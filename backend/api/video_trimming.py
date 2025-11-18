#!/usr/bin/env python3
"""
视频裁剪 API 端点
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
import uuid
import shutil
import sys
from PIL import Image
import io

# 添加项目根目录到路径
sys.path.append(str(Path(__file__).parent.parent))
from utils.video_utils import get_video_info

# 导入你的视频裁剪函数
import cv2
import os

router = APIRouter(prefix="/api/video", tags=["video"])

# 临时文件目录
TEMP_DIR = Path("temp")
TEMP_DIR.mkdir(exist_ok=True)

OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)


@router.post("/info")
async def get_video_information(
    video: UploadFile = File(...),
):
    """
    获取视频信息
    
    Args:
        video: 上传的视频文件
    
    Returns:
        视频信息（fps, 宽度, 高度, 总帧数, 时长）
    """
    try:
        # 保存上传的视频
        temp_id = str(uuid.uuid4())
        temp_video_path = TEMP_DIR / f"{temp_id}_input.mp4"
        
        with open(temp_video_path, "wb") as f:
            shutil.copyfileobj(video.file, f)
        
        print(f"📤 收到视频: {video.filename}")
        
        # 获取视频信息
        info = get_video_info(str(temp_video_path))
        
        print(f"✅ 视频信息: {info}")
        
        # 清理临时文件
        temp_video_path.unlink()
        
        return {
            "success": True,
            "filename": video.filename,
            "info": info
        }
        
    except Exception as e:
        print(f"❌ 获取视频信息失败: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"获取视频信息失败: {str(e)}")


@router.post("/trim")
async def trim_video_frames(
    video: UploadFile = File(...),
    start_frame: int = Form(0),
    end_frame: int = Form(None),
):
    """
    裁剪视频的首尾帧（使用你的 cut_video_frames 函数）

    Args:
        video: 上传的视频文件
        start_frame: 起始帧索引（包含，默认0）
        end_frame: 结束帧索引（包含，None表示到最后一帧）

    Returns:
        裁剪后的视频文件
    """
    temp_input_path = None
    temp_output_path = None

    try:
        # 保存上传的视频
        temp_id = str(uuid.uuid4())
        temp_input_path = TEMP_DIR / f"{temp_id}_input.mp4"
        temp_output_path = TEMP_DIR / f"{temp_id}_output.mp4"

        with open(temp_input_path, "wb") as f:
            shutil.copyfileobj(video.file, f)

        print(f"📤 收到视频: {video.filename}")
        print(f"🔧 开始裁剪视频...")
        print(f"   起始帧: {start_frame}")
        print(f"   结束帧: {end_frame if end_frame is not None else '最后一帧'}")

        # 使用你的 cut_video_by_frames 函数
        success = cut_video_by_frames(
            str(temp_input_path),
            str(temp_output_path),
            start_frame,
            end_frame if end_frame is not None else 999999  # 大数字表示到最后
        )

        if not success:
            raise Exception("视频裁剪失败")

        print(f"✅ 视频裁剪完成: {temp_output_path}")

        # 返回结果（使用 background 参数在响应后删除文件）
        return FileResponse(
            str(temp_output_path),
            media_type="video/mp4",
            filename=f"trimmed_{video.filename}",
            headers={"Content-Disposition": f"attachment; filename=trimmed_{video.filename}"},
            background=cleanup_temp_files(temp_input_path, temp_output_path)
        )

    except Exception as e:
        print(f"❌ 视频裁剪失败: {e}")
        import traceback
        traceback.print_exc()

        # 清理临时文件
        cleanup_func = cleanup_temp_files(temp_input_path, temp_output_path)
        cleanup_func()

        raise HTTPException(status_code=500, detail=f"视频裁剪失败: {str(e)}")


def cleanup_temp_files(input_path, output_path):
    """清理临时文件（同步版本）"""
    def cleanup():
        try:
            if input_path and input_path.exists():
                input_path.unlink()
                print(f"🗑️ 已删除临时输入文件: {input_path}")
        except Exception as e:
            print(f"⚠️ 删除临时输入文件失败: {e}")

        try:
            if output_path and output_path.exists():
                output_path.unlink()
                print(f"🗑️ 已删除临时输出文件: {output_path}")
        except Exception as e:
            print(f"⚠️ 删除临时输出文件失败: {e}")

    return cleanup


def cut_video_by_frames(input_path, output_path, start_frame, end_frame):
    """
    根据起始帧和终止帧剪切视频（从你的 cut_video_frames.py 复制）

    Args:
        input_path (str): 输入视频文件路径
        output_path (str): 输出视频文件路径
        start_frame (int): 起始帧（从0开始计数）
        end_frame (int): 终止帧（包含该帧）
    """
    # 检查输入视频文件是否存在
    if not os.path.exists(input_path):
        print(f"错误：视频文件不存在 - {input_path}")
        return False

    # 验证帧数参数
    if start_frame < 0:
        print(f"错误：起始帧不能小于0")
        return False

    if end_frame <= start_frame:
        print(f"错误：终止帧({end_frame})必须大于起始帧({start_frame})")
        return False

    # 打开输入视频
    cap = cv2.VideoCapture(input_path)

    if not cap.isOpened():
        print(f"错误：无法打开视频文件 - {input_path}")
        return False

    # 获取视频属性
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    print(f"原视频信息:")
    print(f"  分辨率: {width}x{height}")
    print(f"  帧率: {fps:.2f} FPS")
    print(f"  总帧数: {total_frames}")
    print(f"  原视频时长: {total_frames/fps:.2f}秒")

    # 验证帧数范围
    if start_frame >= total_frames:
        print(f"错误：起始帧({start_frame})超出视频范围(0-{total_frames-1})")
        cap.release()
        return False

    # 调整终止帧，不能超出视频范围
    actual_end_frame = min(end_frame, total_frames - 1)
    if actual_end_frame != end_frame:
        print(f"警告：终止帧已调整为 {actual_end_frame}（原视频最大帧数为 {total_frames-1}）")

    frames_to_extract = actual_end_frame - start_frame + 1

    print(f"剪切设置:")
    print(f"  起始帧: {start_frame}")
    print(f"  终止帧: {actual_end_frame}")
    print(f"  提取帧数: {frames_to_extract}")
    print(f"  剪切片段时长: {frames_to_extract/fps:.2f}秒")

    # 创建输出目录（如果不存在）
    output_dir = os.path.dirname(output_path)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # 设置视频编码器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    if not out.isOpened():
        print(f"错误：无法创建输出视频文件 - {output_path}")
        cap.release()
        return False

    # 跳转到起始帧
    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

    # 读取并写入指定范围的帧
    frame_count = 0
    current_frame = start_frame

    while current_frame <= actual_end_frame:
        ret, frame = cap.read()

        if not ret:
            print(f"警告：在第 {current_frame} 帧处读取失败")
            break

        out.write(frame)
        frame_count += 1
        current_frame += 1

        # 显示进度
        if frame_count % 10 == 0 or current_frame > actual_end_frame:
            progress = (frame_count / frames_to_extract) * 100
            print(f"处理进度: {frame_count}/{frames_to_extract} 帧 ({progress:.1f}%)")

    # 释放资源
    cap.release()
    out.release()

    print(f"成功！剪切后的视频已保存到: {output_path}")
    print(f"新视频包含 {frame_count} 帧")

    return True


def extract_frame(video_path: str, frame_index: int, output_path: str) -> bool:
    """
    从视频中提取指定帧并保存为图片

    Args:
        video_path: 输入视频路径
        frame_index: 要提取的帧索引（0表示第一帧，-1表示最后一帧）
        output_path: 输出图片路径

    Returns:
        bool: 是否成功
    """
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        print(f"错误：无法打开视频文件 - {video_path}")
        return False

    # 获取视频信息
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # 处理负索引（-1表示最后一帧）
    if frame_index < 0:
        frame_index = total_frames + frame_index

    # 验证帧索引
    if frame_index < 0 or frame_index >= total_frames:
        print(f"错误：帧索引 {frame_index} 超出范围 (0-{total_frames-1})")
        cap.release()
        return False

    # 跳转到指定帧
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)

    # 读取帧
    ret, frame = cap.read()
    cap.release()

    if not ret:
        print(f"错误：无法读取第 {frame_index} 帧")
        return False

    # 保存为图片
    cv2.imwrite(output_path, frame)
    print(f"✅ 成功提取第 {frame_index} 帧并保存到: {output_path}")

    return True


@router.post("/extract-frame")
async def extract_frame_endpoint(
    video: UploadFile = File(...),
    frame_type: str = Form(...),  # "first" 或 "last"
):
    """
    从视频中提取首帧或尾帧

    Args:
        video: 视频文件
        frame_type: "first" 表示首帧，"last" 表示尾帧

    Returns:
        图片文件
    """
    try:
        # 生成唯一文件名
        file_id = str(uuid.uuid4())
        temp_input_path = TEMP_DIR / f"{file_id}_input.mp4"
        temp_output_path = TEMP_DIR / f"{file_id}_frame.jpg"

        # 保存上传的视频
        with open(temp_input_path, "wb") as buffer:
            shutil.copyfileobj(video.file, buffer)

        print(f"📤 收到视频: {video.filename}")
        print(f"📍 提取类型: {frame_type}")

        # 确定要提取的帧索引
        if frame_type == "first":
            frame_index = 0
            print("📸 提取首帧（第0帧）")
        elif frame_type == "last":
            frame_index = -1
            print("📸 提取尾帧（最后一帧）")
        else:
            raise HTTPException(status_code=400, detail=f"无效的 frame_type: {frame_type}，必须是 'first' 或 'last'")

        # 提取帧
        success = extract_frame(
            str(temp_input_path),
            frame_index,
            str(temp_output_path)
        )

        if not success:
            raise HTTPException(status_code=500, detail="提取帧失败")

        # 返回图片文件
        return FileResponse(
            str(temp_output_path),
            media_type="image/jpeg",
            filename=f"{frame_type}_frame_{video.filename.rsplit('.', 1)[0]}.jpg",
            headers={"Content-Disposition": f"attachment; filename={frame_type}_frame.jpg"},
            background=cleanup_temp_files(temp_input_path, temp_output_path)
        )

    except Exception as e:
        print(f"❌ 提取帧失败: {e}")
        # 清理临时文件
        if temp_input_path.exists():
            temp_input_path.unlink()
        if temp_output_path.exists():
            temp_output_path.unlink()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def health_check():
    """健康检查"""
    return {
        "status": "healthy",
        "service": "video_trimming"
    }

