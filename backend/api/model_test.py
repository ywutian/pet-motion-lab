#!/usr/bin/env python3
"""
可灵AI模型测试API - 测试各模型的首尾帧支持情况
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from pathlib import Path
import shutil
import time
import base64
import tempfile
import traceback

from kling_api_helper import KlingAPI
from config import (
    KLING_ACCESS_KEY,
    KLING_SECRET_KEY,
    KLING_VIDEO_ACCESS_KEY,
    KLING_VIDEO_SECRET_KEY,
)

router = APIRouter(prefix="/api/kling/model-test", tags=["model-test"])

# 可灵AI凭证
# 图片 API
ACCESS_KEY = KLING_ACCESS_KEY
SECRET_KEY = KLING_SECRET_KEY
# 视频 API（独立账户）
VIDEO_ACCESS_KEY = KLING_VIDEO_ACCESS_KEY
VIDEO_SECRET_KEY = KLING_VIDEO_SECRET_KEY

# 临时目录
TEMP_DIR = Path(tempfile.gettempdir()) / "pet_motion_lab" / "model_test"
TEMP_DIR.mkdir(parents=True, exist_ok=True)


# ============================================
# 视频模型配置
# ============================================

# 需要测试的模型（首尾帧支持情况未确认）
VIDEO_MODELS_TO_TEST = [
    {
        "model_name": "kling-v1-5",
        "modes": ["pro"],  # 只测试pro模式，std模式通常不支持首尾帧
        "tail_support": "unknown",
        "price_5s": {"pro": "$0.21"},
        "note": "🔥 需要测试！有报道说支持首尾帧(高品质模式)，如支持可作为便宜备选",
        "test_priority": "high",
    },
    {
        "model_name": "kling-v1-6",
        "modes": ["pro"],
        "tail_support": "unknown",
        "price_5s": {"pro": "$0.28"},
        "note": "🔥 需要测试！官方说v2.1比v1.6效果提升235%，暗示v1.6也有首尾帧功能",
        "test_priority": "high",
    },
]

# 已确认支持首尾帧的模型
VIDEO_MODELS_CONFIRMED = [
    {
        "model_name": "kling-v2-5-turbo",
        "modes": ["pro"],
        "tail_support": "confirmed",
        "price_5s": {"pro": "$0.35"},
        "note": "✅ 已确认支持！官方确认，性价比最高，推荐使用",
        "test_priority": "none",
    },
    {
        "model_name": "kling-v2-1",
        "modes": ["pro"],
        "tail_support": "confirmed",
        "price_5s": {"pro": "$0.49"},
        "note": "✅ 已确认支持！官方明确说明支持首尾帧",
        "test_priority": "none",
    },
]

# 已确认不支持首尾帧的模型
VIDEO_MODELS_NO_TAIL = [
    {
        "model_name": "kling-v2-1-master",
        "modes": ["master"],
        "tail_support": "not_supported",
        "price_5s": {"master": "$1.40"},
        "note": "❌ 不支持首尾帧！API返回: Image tail is not supported by the current model",
        "test_priority": "none",
    },
]

# 不推荐测试的模型（太旧或没有测试价值）
VIDEO_MODELS_SKIP = [
    {
        "model_name": "kling-v1",
        "modes": ["pro"],
        "tail_support": "unlikely",
        "price_5s": {"pro": "$0.21"},
        "note": "⚠️ 不推荐测试：太旧，即使支持首尾帧质量也差",
        "test_priority": "skip",
    },
    {
        "model_name": "kling-v2",
        "modes": ["pro"],
        "tail_support": "unlikely",
        "price_5s": {"pro": "$0.35"},
        "note": "⚠️ 不推荐测试：有v2.5-turbo可用，没有测试价值",
        "test_priority": "skip",
    },
]

# 合并所有模型供API返回
VIDEO_MODELS = VIDEO_MODELS_TO_TEST + VIDEO_MODELS_CONFIRMED + VIDEO_MODELS_NO_TAIL + VIDEO_MODELS_SKIP

# 图片模型配置
IMAGE_MODELS = [
    {
        "model_name": "kling-v1",
        "note": "1.0版本图生图",
    },
    {
        "model_name": "kling-v2",
        "note": "2.0版本图生图（当前使用）",
    },
    {
        "model_name": "kolors",
        "note": "可图1.0，艺术风格",
    },
    {
        "model_name": "kolors-2",
        "note": "可图2.0，电影质感",
    },
]


@router.get("/models")
async def get_available_models():
    """
    获取所有可用的模型配置列表（按测试优先级分类）
    """
    return JSONResponse({
        # 需要测试的模型（首尾帧支持未确认）
        "models_to_test": VIDEO_MODELS_TO_TEST,
        # 已确认支持首尾帧的模型
        "models_confirmed": VIDEO_MODELS_CONFIRMED,
        # 不推荐测试的模型
        "models_skip": VIDEO_MODELS_SKIP,
        # 所有模型（兼容旧版）
        "video_models": VIDEO_MODELS,
        # 图片模型
        "image_models": IMAGE_MODELS,
        # 首尾帧参数名
        "tail_image_param": "image_tail",
        # 说明
        "note": "test_priority: high=需要测试, none=已确认无需测试, skip=不推荐测试",
        "summary": {
            "to_test_count": len(VIDEO_MODELS_TO_TEST),
            "confirmed_count": len(VIDEO_MODELS_CONFIRMED),
            "skip_count": len(VIDEO_MODELS_SKIP),
        }
    })


@router.post("/test-video-model")
async def test_video_model(
    file: UploadFile = File(...),
    model_name: str = Form(...),
    mode: str = Form("pro"),
    test_tail_image: bool = Form(True),
    tail_file: UploadFile = File(None),
):
    """
    测试视频模型是否可用，以及是否支持首尾帧
    
    Args:
        file: 首帧图片
        model_name: 模型名称
        mode: 生成模式 (std/pro/master)
        test_tail_image: 是否测试首尾帧功能
        tail_file: 尾帧图片（可选，如果test_tail_image为True但未提供，则使用首帧作为尾帧）
    
    Returns:
        测试结果，包含模型是否可用、首尾帧是否支持等信息
    """
    timestamp = int(time.time())
    first_frame_path = None
    tail_frame_path = None
    
    try:
        # 保存首帧图片
        first_frame_path = TEMP_DIR / f"test_first_{timestamp}_{file.filename}"
        with open(first_frame_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # 如果测试首尾帧，必须上传尾帧
        if test_tail_image:
            if tail_file:
                tail_frame_path = TEMP_DIR / f"test_tail_{timestamp}_{tail_file.filename}"
                with open(tail_frame_path, "wb") as buffer:
                    shutil.copyfileobj(tail_file.file, buffer)
            else:
                # 必须上传尾帧，不再使用首帧作为默认
                return JSONResponse({
                    "success": False,
                    "model_name": model_name,
                    "mode": mode,
                    "error": "测试首尾帧功能必须上传尾帧图片",
                    "tail_image_tested": False,
                }, status_code=400)
        
        print(f"\n{'='*60}")
        print(f"🧪 模型测试: {model_name} ({mode})")
        print(f"   首帧: {first_frame_path}")
        print(f"   测试首尾帧: {test_tail_image}")
        if tail_frame_path:
            print(f"   尾帧: {tail_frame_path}")
        print(f"{'='*60}")
        
        # 创建API实例（使用视频专用 API 密钥）
        kling = KlingAPI(VIDEO_ACCESS_KEY, VIDEO_SECRET_KEY)
        
        # 读取首帧图片
        with open(first_frame_path, 'rb') as f:
            first_image_base64 = base64.b64encode(f.read()).decode('utf-8')
        
        # 构建请求payload - 使用幼年金毛的提示词
        prompt = "皮克斯风格3D卡通，可爱圆润的造型，大眼睛，一只幼年金毛犬，金色毛发，毛茸茸的质感，轻微呼吸动作，保持自然姿势，纯白色背景，柔和均匀的灯光"
        
        # 调用API
        result = kling.image_to_video(
            image_path=str(first_frame_path),
            prompt=prompt,
            duration=5,
            aspect_ratio="16:9",
            model_name=model_name,
            mode=mode,
            tail_image_path=str(tail_frame_path) if test_tail_image and tail_frame_path else None
        )
        
        task_id = result.get('task_id')
        
        if task_id:
            print(f"✅ 任务创建成功! task_id: {task_id}")
            
            # 等待几秒后查询状态
            time.sleep(5)
            
            try:
                task_data = kling.query_video_task(task_id)
                status = "unknown"
                if 'data' in task_data and 'task_status' in task_data['data']:
                    status = task_data['data']['task_status']
                
                return JSONResponse({
                    "success": True,
                    "model_name": model_name,
                    "mode": mode,
                    "task_id": task_id,
                    "task_status": status,
                    "tail_image_tested": test_tail_image,
                    "tail_image_accepted": True if test_tail_image else None,
                    "message": f"模型 {model_name} ({mode}) 可用" + (", 首尾帧参数已接受" if test_tail_image else ""),
                    "note": "任务已创建，请等待完成后查看视频效果来确认首尾帧是否真正生效"
                })
            except Exception as query_error:
                return JSONResponse({
                    "success": True,
                    "model_name": model_name,
                    "mode": mode,
                    "task_id": task_id,
                    "task_status": "created",
                    "tail_image_tested": test_tail_image,
                    "tail_image_accepted": True if test_tail_image else None,
                    "message": f"任务已创建，但查询状态失败: {str(query_error)}",
                })
        else:
            return JSONResponse({
                "success": False,
                "model_name": model_name,
                "mode": mode,
                "error": "未返回task_id",
                "tail_image_tested": test_tail_image,
            }, status_code=400)
            
    except Exception as e:
        error_msg = str(e)
        error_trace = traceback.format_exc()
        print(f"❌ 测试失败: {error_msg}")
        print(error_trace)
        
        # 分析错误类型
        tail_support_hint = None
        if test_tail_image:
            if "image_tail" in error_msg.lower() or "tail" in error_msg.lower():
                tail_support_hint = "模型可能不支持首尾帧参数"
            elif "invalid" in error_msg.lower() and "model" in error_msg.lower():
                tail_support_hint = "模型名称可能无效"
            elif "mode" in error_msg.lower():
                tail_support_hint = "生成模式可能不支持"
        
        return JSONResponse({
            "success": False,
            "model_name": model_name,
            "mode": mode,
            "error": error_msg,
            "tail_image_tested": test_tail_image,
            "tail_support_hint": tail_support_hint,
            "error_trace": error_trace[:500] if len(error_trace) > 500 else error_trace,
        }, status_code=400)
        
    finally:
        # 清理临时文件
        if first_frame_path and first_frame_path.exists():
            try:
                first_frame_path.unlink()
            except:
                pass
        if tail_frame_path and tail_frame_path != first_frame_path and tail_frame_path.exists():
            try:
                tail_frame_path.unlink()
            except:
                pass


@router.post("/test-image-model")
async def test_image_model(
    file: UploadFile = File(...),
    model_name: str = Form("kling-v2"),
    prompt: str = Form("A cute pet in cartoon style"),
):
    """
    测试图片生成模型是否可用
    
    Args:
        file: 输入图片
        model_name: 模型名称
        prompt: 提示词
    
    Returns:
        测试结果
    """
    timestamp = int(time.time())
    upload_path = None
    
    try:
        # 保存上传的图片
        upload_path = TEMP_DIR / f"test_img_{timestamp}_{file.filename}"
        with open(upload_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        print(f"\n{'='*60}")
        print(f"🧪 图片模型测试: {model_name}")
        print(f"   输入图片: {upload_path}")
        print(f"   提示词: {prompt}")
        print(f"{'='*60}")
        
        # 创建API实例
        kling = KlingAPI(ACCESS_KEY, SECRET_KEY)
        
        # 调用图生图API
        result = kling.image_to_image(
            image_path=str(upload_path),
            prompt=prompt,
            aspect_ratio="1:1",
            image_count=1,
        )
        
        task_id = result.get('task_id')
        
        if task_id:
            print(f"✅ 任务创建成功! task_id: {task_id}")
            
            return JSONResponse({
                "success": True,
                "model_name": model_name,
                "task_id": task_id,
                "message": f"图片模型 {model_name} 可用",
            })
        else:
            return JSONResponse({
                "success": False,
                "model_name": model_name,
                "error": "未返回task_id",
            }, status_code=400)
            
    except Exception as e:
        error_msg = str(e)
        print(f"❌ 测试失败: {error_msg}")
        
        return JSONResponse({
            "success": False,
            "model_name": model_name,
            "error": error_msg,
        }, status_code=400)
        
    finally:
        # 清理临时文件
        if upload_path and upload_path.exists():
            try:
                upload_path.unlink()
            except:
                pass


@router.get("/task-status/{task_id}")
async def get_task_status(task_id: str, task_type: str = "video"):
    """
    查询任务状态
    
    Args:
        task_id: 任务ID
        task_type: 任务类型 (video/image)
    
    Returns:
        任务状态信息
    """
    try:
        kling = KlingAPI(ACCESS_KEY, SECRET_KEY)
        
        if task_type == "video":
            task_data = kling.query_video_task(task_id)
        else:
            task_data = kling.query_task(task_id)
        
        # 提取状态
        status = "unknown"
        result_url = None
        
        if 'data' in task_data:
            data = task_data['data']
            status = data.get('task_status', 'unknown')
            
            if 'task_result' in data:
                task_result = data['task_result']
                if task_type == "video" and 'videos' in task_result:
                    if len(task_result['videos']) > 0:
                        result_url = task_result['videos'][0].get('url')
                elif 'images' in task_result:
                    if len(task_result['images']) > 0:
                        result_url = task_result['images'][0].get('url')
        
        return JSONResponse({
            "task_id": task_id,
            "task_type": task_type,
            "status": status,
            "result_url": result_url,
            "raw_data": task_data,
        })
        
    except Exception as e:
        return JSONResponse({
            "task_id": task_id,
            "error": str(e),
        }, status_code=400)

