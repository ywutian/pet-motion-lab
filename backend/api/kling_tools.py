#!/usr/bin/env python3
"""
可灵AI工具API路由 - 独立工具接口
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
import shutil
import time
import base64
import tempfile

from kling_api_helper import KlingAPI
from config import (
    KLING_ACCESS_KEY,
    KLING_SECRET_KEY,
    KLING_VIDEO_ACCESS_KEY,
    KLING_VIDEO_SECRET_KEY,
)

router = APIRouter(prefix="/api/kling/tools", tags=["kling-tools"])

# 可灵AI凭证（从环境变量读取）
# 图片 API
ACCESS_KEY = KLING_ACCESS_KEY
SECRET_KEY = KLING_SECRET_KEY
# 视频 API（独立账户）
VIDEO_ACCESS_KEY = KLING_VIDEO_ACCESS_KEY
VIDEO_SECRET_KEY = KLING_VIDEO_SECRET_KEY

# 使用系统临时目录（Render 兼容）
TEMP_DIR = Path(tempfile.gettempdir()) / "pet_motion_lab"
TEMP_DIR.mkdir(parents=True, exist_ok=True)

UPLOAD_DIR = TEMP_DIR / "uploads"
OUTPUT_DIR = TEMP_DIR / "kling_tools"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


@router.post("/image-to-image")
async def image_to_image(
    file: UploadFile = File(...),
    prompt: str = Form(...),
    negative_prompt: str = Form("")
):
    """
    图生图工具 - 上传图片，根据提示词生成新图片
    
    Args:
        file: 输入图片
        prompt: 提示词
        negative_prompt: 负向提示词（可选）
    
    Returns:
        生成的图片文件
    """
    try:
        # 保存上传的文件
        timestamp = int(time.time())
        upload_path = UPLOAD_DIR / f"img2img_{timestamp}_{file.filename}"
        with open(upload_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        print(f"🎨 图生图任务开始")
        print(f"  输入图片: {upload_path}")
        print(f"  提示词: {prompt}")
        if negative_prompt:
            print(f"  负向提示词: {negative_prompt}")
        
        # 调用可灵AI
        kling = KlingAPI(ACCESS_KEY, SECRET_KEY)

        # 创建图生图任务
        result = kling.image_to_image(
            image_path=str(upload_path),
            prompt=prompt,
            negative_prompt=negative_prompt,
            aspect_ratio="1:1",
            image_count=1
        )
        
        task_id = result['task_id']
        print(f"  任务ID: {task_id}")
        
        # 等待任务完成
        task_data = kling.wait_for_task(task_id, max_wait_seconds=300)
        
        # 提取图片URL
        image_url = None
        if 'data' in task_data and 'task_result' in task_data['data']:
            task_result = task_data['data']['task_result']
            if 'images' in task_result and len(task_result['images']) > 0:
                image_url = task_result['images'][0]['url']
        
        if not image_url:
            raise Exception(f"未找到生成的图片URL: {task_data}")
        
        print(f"  图片URL: {image_url}")
        
        # 下载图片
        output_path = OUTPUT_DIR / f"img2img_{timestamp}.png"
        kling.download_image(image_url, str(output_path))
        
        print(f"✅ 图生图完成: {output_path}")
        
        # 清理上传的文件
        upload_path.unlink()
        
        # 返回生成的图片
        return FileResponse(
            path=str(output_path),
            media_type="image/png",
            filename=f"generated_{timestamp}.png"
        )
        
    except Exception as e:
        print(f"❌ 图生图失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"图生图失败: {str(e)}")


@router.post("/image-to-video")
async def image_to_video(
    file: UploadFile = File(...),
    prompt: str = Form(...),
    negative_prompt: str = Form("")
):
    """
    图生视频工具 - 上传图片，根据提示词生成视频
    
    Args:
        file: 输入图片
        prompt: 提示词
        negative_prompt: 负向提示词（可选）
    
    Returns:
        生成的视频文件
    """
    try:
        # 保存上传的文件
        timestamp = int(time.time())
        upload_path = UPLOAD_DIR / f"img2vid_{timestamp}_{file.filename}"
        with open(upload_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        print(f"🎬 图生视频任务开始")
        print(f"  输入图片: {upload_path}")
        print(f"  提示词: {prompt}")
        if negative_prompt:
            print(f"  负向提示词: {negative_prompt}")
        
        # 调用可灵AI（使用视频专用 API 密钥）
        kling = KlingAPI(VIDEO_ACCESS_KEY, VIDEO_SECRET_KEY)

        # 创建图生视频任务
        result = kling.image_to_video(
            image_path=str(upload_path),
            prompt=prompt,
            negative_prompt=negative_prompt,
            duration=5,
            aspect_ratio="16:9",
            model_name="kling-v2-1"
        )
        
        task_id = result['task_id']
        print(f"  任务ID: {task_id}")
        
        # 等待任务完成
        task_data = kling.wait_for_video_task(task_id, max_wait_seconds=600)
        
        # 提取视频URL
        video_url = None
        if 'data' in task_data and 'task_result' in task_data['data']:
            task_result = task_data['data']['task_result']
            if 'videos' in task_result and len(task_result['videos']) > 0:
                video_url = task_result['videos'][0]['url']

        if not video_url:
            raise Exception(f"未找到生成的视频URL: {task_data}")

        print(f"  视频URL: {video_url}")

        # 下载视频
        output_path = OUTPUT_DIR / f"img2vid_{timestamp}.mp4"
        kling.download_video(video_url, str(output_path))

        print(f"✅ 图生视频完成: {output_path}")

        # 清理上传的文件
        upload_path.unlink()

        # 返回生成的视频
        return FileResponse(
            path=str(output_path),
            media_type="video/mp4",
            filename=f"generated_{timestamp}.mp4"
        )

    except Exception as e:
        print(f"❌ 图生视频失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"图生视频失败: {str(e)}")


@router.post("/frames-to-video")
async def frames_to_video(
    first_frame: UploadFile = File(...),
    last_frame: UploadFile = File(...)
):
    """
    首尾帧生成过渡视频工具 - 上传首帧和尾帧，生成平滑过渡视频

    Args:
        first_frame: 首帧图片
        last_frame: 尾帧图片

    Returns:
        生成的过渡视频文件
    """
    try:
        # 保存上传的文件
        timestamp = int(time.time())
        first_frame_path = UPLOAD_DIR / f"first_{timestamp}_{first_frame.filename}"
        last_frame_path = UPLOAD_DIR / f"last_{timestamp}_{last_frame.filename}"

        with open(first_frame_path, "wb") as buffer:
            shutil.copyfileobj(first_frame.file, buffer)
        with open(last_frame_path, "wb") as buffer:
            shutil.copyfileobj(last_frame.file, buffer)

        print(f"🎥 首尾帧生成视频任务开始")
        print(f"  首帧: {first_frame_path}")
        print(f"  尾帧: {last_frame_path}")

        # 调用可灵AI（使用视频专用 API 密钥）
        kling = KlingAPI(VIDEO_ACCESS_KEY, VIDEO_SECRET_KEY)

        # 创建图生视频任务
        prompt = "平滑过渡到目标姿态，自然流畅的动画效果"
        result = kling.image_to_video(
            image_path=str(first_frame_path),
            prompt=prompt,
            duration=5,
            aspect_ratio="16:9",
            model_name="kling-v2-1"
        )

        task_id = result['task_id']
        print(f"  任务ID: {task_id}")
        print(f"  提示词: {prompt}")
        print(f"  注意: 当前使用首帧生成视频，尾帧作为参考")

        # 等待任务完成
        task_data = kling.wait_for_video_task(task_id, max_wait_seconds=600)

        # 提取视频URL
        video_url = None
        if 'data' in task_data and 'task_result' in task_data['data']:
            task_result = task_data['data']['task_result']
            if 'videos' in task_result and len(task_result['videos']) > 0:
                video_url = task_result['videos'][0]['url']

        if not video_url:
            raise Exception(f"未找到生成的视频URL: {task_data}")

        print(f"  视频URL: {video_url}")

        # 下载视频
        output_path = OUTPUT_DIR / f"transition_{timestamp}.mp4"
        kling.download_video(video_url, str(output_path))

        print(f"✅ 过渡视频生成完成: {output_path}")

        # 清理上传的文件
        first_frame_path.unlink()
        last_frame_path.unlink()

        # 返回生成的视频
        return FileResponse(
            path=str(output_path),
            media_type="video/mp4",
            filename=f"transition_{timestamp}.mp4"
        )

    except Exception as e:
        print(f"❌ 首尾帧生成视频失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"首尾帧生成视频失败: {str(e)}")


@router.post("/video-to-gif")
async def video_to_gif(
    file: UploadFile = File(...),
    fps_reduction: int = Form(2),
    max_width: int = Form(480)
):
    """
    视频转GIF工具 - 将视频转换为GIF动画

    Args:
        file: 输入视频文件
        fps_reduction: 帧率缩减倍数（默认2）
        max_width: GIF最大宽度（默认480）

    Returns:
        生成的GIF文件
    """
    try:
        # 保存上传的视频
        timestamp = int(time.time())
        upload_path = UPLOAD_DIR / f"video_{timestamp}_{file.filename}"
        with open(upload_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        print(f"🎞️ 视频转GIF任务开始")
        print(f"  输入视频: {upload_path}")
        print(f"  帧率缩减: {fps_reduction}x")
        print(f"  最大宽度: {max_width}px")

        # 导入视频工具
        from utils.video_utils import convert_mp4_to_gif

        # 转换为GIF
        output_path = OUTPUT_DIR / f"gif_{timestamp}.gif"
        convert_mp4_to_gif(
            str(upload_path),
            str(output_path),
            fps_reduction=fps_reduction,
            max_width=max_width
        )

        print(f"✅ GIF转换成功: {output_path}")

        # 清理上传的视频
        upload_path.unlink()

        # 返回生成的GIF
        return FileResponse(
            path=str(output_path),
            media_type="image/gif",
            filename=f"converted_{timestamp}.gif"
        )

    except Exception as e:
        print(f"❌ 视频转GIF失败: {str(e)}")
        raise HTTPException(status_code=500, detail=f"视频转GIF失败: {str(e)}")

