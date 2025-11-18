#!/usr/bin/env python3
"""
图像生成 API 端点（本地模型 - 可选）
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional, List
import sys
from pathlib import Path
import uuid
import shutil

router = APIRouter(prefix="/api/generate", tags=["generation"])

# 延迟导入，避免启动时加载模型
def get_generator():
    """延迟加载生成器"""
    try:
        sys.path.append(str(Path(__file__).parent.parent))
        from services.pipeline_service import get_generator as _get_generator
        return _get_generator()
    except Exception as e:
        raise HTTPException(
            status_code=503,
            detail=f"本地模型未配置或加载失败: {str(e)}。请使用可灵AI接口。"
        )

# 临时文件目录
TEMP_DIR = Path("temp")
TEMP_DIR.mkdir(exist_ok=True)

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)


class GenerationRequest(BaseModel):
    """生成请求"""
    pose: str  # sit, walk, rest, sleep
    prompt: Optional[str] = None
    ip_adapter_scale: Optional[float] = None
    controlnet_scale: Optional[float] = None
    lora_scale: Optional[float] = None
    num_inference_steps: Optional[int] = None
    guidance_scale: Optional[float] = None
    seed: Optional[int] = None


class BatchGenerationRequest(BaseModel):
    """批量生成请求"""
    poses: List[str] = ["sit", "walk", "rest", "sleep"]
    prompt: Optional[str] = None
    ip_adapter_scale: Optional[float] = None
    controlnet_scale: Optional[float] = None
    lora_scale: Optional[float] = None
    num_inference_steps: Optional[int] = None
    guidance_scale: Optional[float] = None
    seed: Optional[int] = None


@router.post("/single")
async def generate_single_image(
    reference_image: UploadFile = File(...),
    pose: str = Form(...),
    prompt: Optional[str] = Form(None),
    ip_adapter_scale: Optional[float] = Form(None),
    controlnet_scale: Optional[float] = Form(None),
    lora_scale: Optional[float] = Form(None),
    num_inference_steps: Optional[int] = Form(None),
    guidance_scale: Optional[float] = Form(None),
    seed: Optional[int] = Form(None),
):
    """
    生成单张图片
    
    Args:
        reference_image: 参考宠物图片
        pose: 姿势 (sit/walk/rest/sleep)
        其他参数: 生成参数（可选）
    
    Returns:
        生成的图片
    """
    try:
        # 保存上传的图片
        temp_id = str(uuid.uuid4())
        temp_image_path = TEMP_DIR / f"{temp_id}_reference.png"
        
        with open(temp_image_path, "wb") as f:
            shutil.copyfileobj(reference_image.file, f)
        
        # 获取生成器
        generator = get_generator()
        
        # 获取姿势骨架路径
        from config import MODEL_PATHS
        pose_image_path = Path(MODEL_PATHS["pose_library"]) / "dog" / f"{pose}.png"
        
        if not pose_image_path.exists():
            raise HTTPException(status_code=400, detail=f"姿势 '{pose}' 不存在")
        
        # 生成图像
        result_image = generator.generate_image(
            reference_image_path=str(temp_image_path),
            pose_image_path=str(pose_image_path),
            prompt=prompt,
            ip_adapter_scale=ip_adapter_scale,
            controlnet_scale=controlnet_scale,
            lora_scale=lora_scale,
            num_inference_steps=num_inference_steps,
            guidance_scale=guidance_scale,
            seed=seed,
        )
        
        # 保存结果
        output_path = OUTPUT_DIR / f"{temp_id}_{pose}.png"
        result_image.save(output_path)
        
        # 清理临时文件
        temp_image_path.unlink()
        
        # 返回图片
        return FileResponse(
            output_path,
            media_type="image/png",
            filename=f"{pose}.png"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/batch")
async def generate_batch_images(
    reference_image: UploadFile = File(...),
    poses: str = Form("sit,walk,rest,sleep"),  # 逗号分隔
    prompt: Optional[str] = Form(None),
    ip_adapter_scale: Optional[float] = Form(None),
    controlnet_scale: Optional[float] = Form(None),
    lora_scale: Optional[float] = Form(None),
    num_inference_steps: Optional[int] = Form(None),
    guidance_scale: Optional[float] = Form(None),
    seed: Optional[int] = Form(None),
):
    """
    批量生成多个姿势的图片
    
    Args:
        reference_image: 参考宠物图片
        poses: 姿势列表（逗号分隔，如 "sit,walk,rest,sleep"）
        其他参数: 生成参数（可选）
    
    Returns:
        包含所有生成图片路径的 JSON
    """
    try:
        # 保存上传的图片
        temp_id = str(uuid.uuid4())
        temp_image_path = TEMP_DIR / f"{temp_id}_reference.png"
        
        with open(temp_image_path, "wb") as f:
            shutil.copyfileobj(reference_image.file, f)
        
        # 解析姿势列表
        pose_list = [p.strip() for p in poses.split(",")]
        
        # 获取生成器
        generator = get_generator()
        
        # 生成所有姿势
        results = {}
        from config import MODEL_PATHS
        
        for pose in pose_list:
            pose_image_path = Path(MODEL_PATHS["pose_library"]) / "dog" / f"{pose}.png"
            
            if not pose_image_path.exists():
                print(f"⚠️ 跳过不存在的姿势: {pose}")
                continue
            
            # 生成图像
            result_image = generator.generate_image(
                reference_image_path=str(temp_image_path),
                pose_image_path=str(pose_image_path),
                prompt=prompt,
                ip_adapter_scale=ip_adapter_scale,
                controlnet_scale=controlnet_scale,
                lora_scale=lora_scale,
                num_inference_steps=num_inference_steps,
                guidance_scale=guidance_scale,
                seed=seed,
            )
            
            # 保存结果
            output_path = OUTPUT_DIR / f"{temp_id}_{pose}.png"
            result_image.save(output_path)
            results[pose] = str(output_path)
        
        # 清理临时文件
        temp_image_path.unlink()
        
        # 返回结果路径
        return JSONResponse({
            "success": True,
            "results": results,
            "message": f"成功生成 {len(results)} 个姿势"
        })
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

