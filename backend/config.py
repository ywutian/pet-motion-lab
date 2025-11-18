import torch
import os
from pathlib import Path

# ============================================
# 加载 .env 文件（本地开发用）
# ============================================
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        print(f"✅ 已加载 .env 文件")
except ImportError:
    # 生产环境不需要 python-dotenv
    pass

# ============================================
# 可灵AI API 配置（从环境变量读取）
# ============================================
KLING_ACCESS_KEY = os.getenv("KLING_ACCESS_KEY", "")
KLING_SECRET_KEY = os.getenv("KLING_SECRET_KEY", "")

if not KLING_ACCESS_KEY or not KLING_SECRET_KEY:
    print("⚠️ 警告: 未设置可灵AI密钥环境变量 (KLING_ACCESS_KEY, KLING_SECRET_KEY)")
    print("   请在环境变量中设置，或在本地开发时使用 .env 文件")

# 检测设备
# 注意：Flux.1-dev + IP-Adapter 需要超过 13GB 内存
# Mac M4 的 MPS 限制是 12.8GB，所以暂时使用 CPU
# 如果有更大内存的 GPU，可以改回 mps 或 cuda
DEVICE = "cpu"  # 使用 CPU 避免 MPS 内存不足
print("⚠️ 使用 CPU（Flux 模型太大，MPS 内存不足）")

# if torch.backends.mps.is_available():
#     DEVICE = "mps"  # Mac M4 GPU
#     print("✅ 使用 Mac M4 GPU (MPS)")
# elif torch.cuda.is_available():
#     DEVICE = "cuda"  # NVIDIA GPU
#     print("✅ 使用 NVIDIA GPU (CUDA)")
# else:
#     DEVICE = "cpu"
#     print("⚠️ 使用 CPU（速度较慢）")

# 模型路径配置（Flux 最佳方案）
MODEL_PATHS = {
    # Flux 基础模型
    "flux_base": "models/flux/flux-dev",
    
    # IP-Adapter
    "ip_adapter": "models/ip_adapter/flux/ip-adapter.bin",
    "image_encoder": "models/ip_adapter/flux/image_encoder",
    
    # ControlNet
    "controlnet_union": "models/controlnet/flux-union",
    
    # LoRA
    "lora_3d": "models/lora/flux-3d",
    
    # 姿势库
    "pose_library": "models/pose_library",
}

# 生成参数（Flux 优化）
GENERATION_CONFIG = {
    # 基础参数
    "num_inference_steps": 28,      # Flux 推荐 28 steps
    "guidance_scale": 3.5,          # Flux 推荐 3.5（比 SDXL 低）
    "width": 1024,
    "height": 1024,
    
    # 控制强度
    "ip_adapter_scale": 0.85,       # IP-Adapter 强度（0-1）
    "controlnet_scale": 0.75,       # ControlNet 强度（0-1）
    "lora_scale": 0.8,              # LoRA 强度（0-1）
    
    # 优化参数
    "max_sequence_length": 256,     # Flux 专用
}

# Prompt 模板
PROMPT_TEMPLATE = {
    "style": "3D cartoon style, Pixar style, cute, high quality, detailed",
    "negative": "realistic, photo, 2D, flat, low quality, blurry, distorted",
}

# Mac M4 优化
if DEVICE == "mps":
    # MPS 优化设置
    try:
        torch.mps.set_per_process_memory_fraction(0.8)  # 使用 80% GPU 内存
        print("⚙️ Mac M4 优化已启用")
    except:
        print("⚙️ Mac M4 优化跳过（PyTorch 版本可能不支持）")

