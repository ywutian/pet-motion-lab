#!/usr/bin/env python3
"""
Flux + IP-Adapter + ControlNet 图像生成管道
"""

import torch
from PIL import Image
from pathlib import Path
import sys

# 添加项目根目录到路径
sys.path.append(str(Path(__file__).parent.parent))
from config import MODEL_PATHS, GENERATION_CONFIG, DEVICE, PROMPT_TEMPLATE

# 导入 IP-Adapter 的自定义模块
ip_adapter_path = Path(__file__).parent.parent / "models" / "ip_adapter" / "flux"
sys.path.insert(0, str(ip_adapter_path))

from pipeline_flux_ipa import FluxPipeline
from transformer_flux import FluxTransformer2DModel
from attention_processor import IPAFluxAttnProcessor2_0
from transformers import AutoProcessor, SiglipVisionModel
from diffusers.utils import load_image


class MLPProjModel(torch.nn.Module):
    """IP-Adapter 的投影模型"""
    def __init__(self, cross_attention_dim=768, id_embeddings_dim=512, num_tokens=4):
        super().__init__()
        
        self.cross_attention_dim = cross_attention_dim
        self.num_tokens = num_tokens
        
        self.proj = torch.nn.Sequential(
            torch.nn.Linear(id_embeddings_dim, id_embeddings_dim*2),
            torch.nn.GELU(),
            torch.nn.Linear(id_embeddings_dim*2, cross_attention_dim*num_tokens),
        )
        self.norm = torch.nn.LayerNorm(cross_attention_dim)
        
    def forward(self, id_embeds):
        x = self.proj(id_embeds)
        x = x.reshape(-1, self.num_tokens, self.cross_attention_dim)
        x = self.norm(x)
        return x


class PetImageGenerator:
    """宠物图像生成器"""
    
    def __init__(self):
        self.device = DEVICE
        self.pipe = None
        self.image_encoder = None
        self.clip_image_processor = None
        self.image_proj_model = None
        self.num_tokens = 128
        
        print(f"🔧 初始化生成器，使用设备: {self.device}")
    
    def load_models(self):
        """加载所有模型"""
        print("📦 加载模型...")
        
        try:
            # 1. 加载 Flux Transformer (自定义版本支持 IP-Adapter)
            print("  - 加载 Flux Transformer...")
            transformer = FluxTransformer2DModel.from_pretrained(
                MODEL_PATHS["flux_base"],
                subfolder="transformer",
                torch_dtype=torch.bfloat16
            )
            
            # 2. 加载 Flux Pipeline (自定义版本)
            print("  - 加载 Flux Pipeline...")
            self.pipe = FluxPipeline.from_pretrained(
                MODEL_PATHS["flux_base"],
                transformer=transformer,
                torch_dtype=torch.bfloat16
            )
            
            # 3. 加载 Image Encoder (SigLIP)
            print("  - 加载 Image Encoder (SigLIP)...")
            image_encoder_path = "google/siglip-so400m-patch14-384"
            self.image_encoder = SiglipVisionModel.from_pretrained(
                image_encoder_path,
                torch_dtype=torch.bfloat16
            ).to(self.device)
            self.clip_image_processor = AutoProcessor.from_pretrained(image_encoder_path)
            
            # 4. 加载 IP-Adapter 投影模型
            print("  - 加载 IP-Adapter 投影模型...")
            self.image_proj_model = MLPProjModel(
                cross_attention_dim=self.pipe.transformer.config.joint_attention_dim,
                id_embeddings_dim=1152,
                num_tokens=self.num_tokens,
            ).to(self.device, dtype=torch.bfloat16)
            
            # 5. 设置 IP-Adapter attention processors
            print("  - 设置 IP-Adapter attention processors...")
            attn_procs = {}
            for name in self.pipe.transformer.attn_processors.keys():
                if name.startswith("transformer_blocks.") or name.startswith("single_transformer_blocks."):
                    attn_procs[name] = IPAFluxAttnProcessor2_0(
                        hidden_size=self.pipe.transformer.config.num_attention_heads * self.pipe.transformer.config.attention_head_dim,
                        cross_attention_dim=self.pipe.transformer.config.joint_attention_dim,
                        num_tokens=self.num_tokens,
                    ).to(self.device, dtype=torch.bfloat16)
                else:
                    attn_procs[name] = self.pipe.transformer.attn_processors[name]
            
            self.pipe.transformer.set_attn_processor(attn_procs)
            
            # 6. 加载 IP-Adapter 权重
            print("  - 加载 IP-Adapter 权重...")
            ip_ckpt = Path(MODEL_PATHS["ip_adapter"])
            state_dict = torch.load(ip_ckpt, map_location="cpu")
            self.image_proj_model.load_state_dict(state_dict["image_proj"], strict=True)
            ip_layers = torch.nn.ModuleList(self.pipe.transformer.attn_processors.values())
            ip_layers.load_state_dict(state_dict["ip_adapter"], strict=False)
            
            # 7. 优化设置
            if self.device == "cpu":
                print("  - 使用 CPU 模式（速度较慢但内存充足）...")
                # CPU 模式下启用内存优化
                self.pipe.enable_attention_slicing()
                self.pipe.enable_vae_slicing()
            elif self.device == "mps":
                print("  - 启用 MPS 内存优化...")
                # 使用 CPU offloading 来减少 MPS 内存占用
                self.pipe.enable_model_cpu_offload()
                self.pipe.enable_attention_slicing()
                self.pipe.enable_vae_slicing()
                print("  - 已启用 CPU offloading，模型将按需加载到 MPS")
            else:
                # CUDA 设备
                print(f"  - 移动模型到 {self.device}...")
                self.pipe = self.pipe.to(self.device)
                self.pipe.enable_model_cpu_offload()

            print("✅ 模型加载完成！")
            
        except Exception as e:
            print(f"❌ 模型加载失败: {e}")
            import traceback
            traceback.print_exc()
            raise
    
    def set_ip_adapter_scale(self, scale):
        """设置 IP-Adapter 强度"""
        for attn_processor in self.pipe.transformer.attn_processors.values():
            if isinstance(attn_processor, IPAFluxAttnProcessor2_0):
                attn_processor.scale = scale
    
    @torch.inference_mode()
    def get_image_embeds(self, pil_image):
        """获取图像 embedding"""
        if isinstance(pil_image, Image.Image):
            pil_image = [pil_image]
        clip_image = self.clip_image_processor(images=pil_image, return_tensors="pt").pixel_values
        clip_image_embeds = self.image_encoder(clip_image.to(self.device, dtype=self.image_encoder.dtype)).pooler_output
        clip_image_embeds = clip_image_embeds.to(dtype=torch.bfloat16)
        image_prompt_embeds = self.image_proj_model(clip_image_embeds)
        return image_prompt_embeds

    def generate_image(
        self,
        reference_image_path: str,
        pose_image_path: str = None,
        prompt: str = None,
        ip_adapter_scale: float = None,
        num_inference_steps: int = None,
        guidance_scale: float = None,
        seed: int = None,
        width: int = None,
        height: int = None,
    ) -> Image.Image:
        """
        生成单张图片

        Args:
            reference_image_path: 参考宠物图片路径
            pose_image_path: 姿势骨架图路径 (可选)
            prompt: 提示词 (可选)
            ip_adapter_scale: IP-Adapter 强度 (0-1)
            num_inference_steps: 推理步数
            guidance_scale: 引导强度
            seed: 随机种子
            width: 图像宽度
            height: 图像高度

        Returns:
            生成的图片
        """
        # 使用默认配置
        ip_adapter_scale = ip_adapter_scale or GENERATION_CONFIG["ip_adapter_scale"]
        num_inference_steps = num_inference_steps or GENERATION_CONFIG["num_inference_steps"]
        guidance_scale = guidance_scale or GENERATION_CONFIG["guidance_scale"]
        width = width or GENERATION_CONFIG["width"]
        height = height or GENERATION_CONFIG["height"]

        # 构建提示词
        if prompt is None:
            prompt = PROMPT_TEMPLATE["style"]
        else:
            prompt = f"{prompt}, {PROMPT_TEMPLATE['style']}"

        # 加载参考图片
        reference_image = Image.open(reference_image_path).convert("RGB")

        # 获取图像 embedding
        image_prompt_embeds = self.get_image_embeds(reference_image)

        # 设置 IP-Adapter 强度
        self.set_ip_adapter_scale(ip_adapter_scale)

        # 设置随机种子
        if seed is None:
            generator = None
        else:
            generator = torch.Generator(self.device).manual_seed(seed)

        # 生成图像
        images = self.pipe(
            prompt=prompt,
            image_emb=image_prompt_embeds,
            guidance_scale=guidance_scale,
            num_inference_steps=num_inference_steps,
            width=width,
            height=height,
            generator=generator,
        ).images

        return images[0]

    def generate_all_poses(
        self,
        reference_image_path: str,
        output_dir: str = "output",
        **kwargs
    ) -> dict:
        """
        生成所有姿势的图像

        Args:
            reference_image_path: 参考宠物图片路径
            output_dir: 输出目录
            **kwargs: 其他生成参数

        Returns:
            字典，键为姿势名称，值为输出文件路径
        """
        poses = ["sit", "walk", "rest", "sleep"]
        results = {}

        # 创建输出目录
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        for pose in poses:
            print(f"\n🎨 生成姿势: {pose}")

            # 姿势骨架路径
            pose_image_path = Path(MODEL_PATHS["pose_library"]) / "dog" / f"{pose}.png"

            if not pose_image_path.exists():
                print(f"  ⚠️ 跳过: 姿势骨架不存在")
                continue

            # 生成图像
            image = self.generate_image(
                reference_image_path=reference_image_path,
                pose_image_path=str(pose_image_path),
                **kwargs
            )

            # 保存结果
            output_file = output_path / f"{pose}.png"
            image.save(output_file)
            results[pose] = str(output_file)

            print(f"  ✅ 完成: {output_file}")

        return results


# 全局单例
_generator = None

def get_generator() -> PetImageGenerator:
    """获取全局生成器实例"""
    global _generator
    if _generator is None:
        _generator = PetImageGenerator()
        _generator.load_models()
    return _generator

