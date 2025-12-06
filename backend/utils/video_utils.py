#!/usr/bin/env python3
"""
视频处理工具函数
封装视频帧提取、转换等功能
"""

import cv2
import os
import io
import requests
from pathlib import Path
from PIL import Image
import numpy as np

# 尝试导入 rembg（可选依赖）
try:
    from rembg import remove as rembg_remove
    from rembg import new_session
    REMBG_AVAILABLE = True
except ImportError:
    REMBG_AVAILABLE = False
    print("⚠️ rembg 未安装，本地去背景功能不可用")


def extract_frame(video_path: str, frame_index: int = -1, output_path: str = None) -> np.ndarray:
    """
    从视频中提取指定帧
    
    Args:
        video_path: 视频文件路径
        frame_index: 帧索引（-1表示最后一帧，0表示第一帧）
        output_path: 输出图片路径（可选）
    
    Returns:
        提取的帧（numpy数组）
    """
    if not os.path.exists(video_path):
        raise FileNotFoundError(f"视频文件不存在: {video_path}")
    
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        raise Exception(f"无法打开视频文件: {video_path}")
    
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    # 处理负索引
    if frame_index < 0:
        frame_index = total_frames + frame_index
    
    # 验证帧索引
    if frame_index < 0 or frame_index >= total_frames:
        cap.release()
        raise ValueError(f"帧索引超出范围: {frame_index}（总帧数: {total_frames}）")
    
    # 跳转到指定帧
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
    
    # 读取帧
    ret, frame = cap.read()
    cap.release()
    
    if not ret:
        raise Exception(f"无法读取第 {frame_index} 帧")
    
    # 保存图片（如果指定了输出路径）
    if output_path:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(output_path, frame)
        print(f"✅ 帧已保存: {output_path}")
    
    return frame


def extract_first_frame(video_path: str, output_path: str) -> str:
    """提取视频第一帧"""
    extract_frame(video_path, frame_index=0, output_path=output_path)
    return output_path


def extract_last_frame(video_path: str, output_path: str) -> str:
    """提取视频最后一帧"""
    extract_frame(video_path, frame_index=-1, output_path=output_path)
    return output_path


def get_video_info(video_path: str) -> dict:
    """
    获取视频信息
    
    Returns:
        包含fps, width, height, total_frames, duration的字典
    """
    if not os.path.exists(video_path):
        raise FileNotFoundError(f"视频文件不存在: {video_path}")
    
    cap = cv2.VideoCapture(video_path)
    
    if not cap.isOpened():
        raise Exception(f"无法打开视频文件: {video_path}")
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps if fps > 0 else 0
    
    cap.release()
    
    return {
        "fps": fps,
        "width": width,
        "height": height,
        "total_frames": total_frames,
        "duration": duration,
    }


def convert_mp4_to_gif(
    input_path: str,
    output_path: str,
    fps_reduction: int = 2,
    max_width: int = 480
) -> str:
    """
    将MP4转换为GIF
    
    Args:
        input_path: 输入MP4路径
        output_path: 输出GIF路径
        fps_reduction: 帧率缩减倍数
        max_width: GIF最大宽度
    
    Returns:
        输出GIF路径
    """
    cap = cv2.VideoCapture(input_path)
    
    if not cap.isOpened():
        raise Exception(f"无法打开视频: {input_path}")
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # 计算缩放
    if width > max_width:
        scale_factor = max_width / width
        new_width = max_width
        new_height = int(height * scale_factor)
    else:
        new_width = width
        new_height = height
        scale_factor = 1.0
    
    # 读取帧
    frames = []
    frame_count = 0
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        # 跳帧
        if frame_count % fps_reduction == 0:
            # BGR转RGB
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # 缩放
            if scale_factor != 1.0:
                frame_rgb = cv2.resize(frame_rgb, (new_width, new_height))
            
            # 转PIL Image
            pil_image = Image.fromarray(frame_rgb)
            frames.append(pil_image)
        
        frame_count += 1
    
    cap.release()
    
    if not frames:
        raise Exception("没有读取到任何帧")
    
    # 计算GIF帧间隔
    gif_fps = fps / fps_reduction
    frame_duration = int(1000 / gif_fps)
    
    # 保存GIF
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=frame_duration,
        loop=0,
        optimize=True
    )
    
    print(f"✅ GIF已保存: {output_path}")
    return output_path


def trim_video(
    input_path: str,
    output_path: str,
    start_frame: int = 0,
    end_frame: int = None
) -> str:
    """
    裁剪视频的首尾帧

    Args:
        input_path: 输入视频路径
        output_path: 输出视频路径
        start_frame: 起始帧索引（包含，默认0）
        end_frame: 结束帧索引（包含，None表示到最后一帧）

    Returns:
        输出视频路径
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"视频文件不存在: {input_path}")

    cap = cv2.VideoCapture(input_path)

    if not cap.isOpened():
        raise Exception(f"无法打开视频: {input_path}")

    # 获取视频信息
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # 处理结束帧
    if end_frame is None:
        end_frame = total_frames - 1

    # 验证帧范围
    if start_frame < 0 or start_frame >= total_frames:
        cap.release()
        raise ValueError(f"起始帧超出范围: {start_frame}（总帧数: {total_frames}）")

    if end_frame < start_frame or end_frame >= total_frames:
        cap.release()
        raise ValueError(f"结束帧超出范围: {end_frame}（总帧数: {total_frames}）")

    # 创建输出目录
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    # 创建视频写入器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    # 跳转到起始帧
    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

    # 读取并写入帧
    current_frame = start_frame
    frames_written = 0

    while current_frame <= end_frame:
        ret, frame = cap.read()
        if not ret:
            break

        out.write(frame)
        frames_written += 1
        current_frame += 1

    cap.release()
    out.release()

    print(f"✅ 视频已裁剪: {output_path}")
    print(f"   原始帧数: {total_frames}, 裁剪后帧数: {frames_written}")
    print(f"   裁剪范围: 第 {start_frame} 帧 到 第 {end_frame} 帧")

    return output_path


def concatenate_videos(
    video_paths: list,
    output_path: str,
    resize_to_first: bool = True
) -> str:
    """
    拼接多个视频文件
    
    Args:
        video_paths: 视频文件路径列表（按顺序）
        output_path: 输出视频路径
        resize_to_first: 是否将所有视频调整为第一个视频的尺寸（默认True）
    
    Returns:
        输出视频路径
    """
    if not video_paths:
        raise ValueError("视频路径列表不能为空")
    
    # 检查所有视频文件是否存在
    for video_path in video_paths:
        if not os.path.exists(video_path):
            raise FileNotFoundError(f"视频文件不存在: {video_path}")
    
    # 获取第一个视频的信息作为参考
    first_cap = cv2.VideoCapture(video_paths[0])
    if not first_cap.isOpened():
        raise Exception(f"无法打开第一个视频: {video_paths[0]}")
    
    fps = first_cap.get(cv2.CAP_PROP_FPS)
    width = int(first_cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(first_cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    first_cap.release()
    
    # 创建输出目录
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    
    # 创建视频写入器
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    if not out.isOpened():
        raise Exception(f"无法创建输出视频文件: {output_path}")
    
    total_frames = 0
    
    # 逐个处理每个视频
    for i, video_path in enumerate(video_paths):
        print(f"📹 处理视频 {i+1}/{len(video_paths)}: {Path(video_path).name}")
        
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            print(f"⚠️  警告: 无法打开视频 {video_path}，跳过")
            cap.release()
            continue
        
        video_fps = cap.get(cv2.CAP_PROP_FPS)
        video_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        video_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        video_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        print(f"   尺寸: {video_width}x{video_height}, FPS: {video_fps:.2f}, 帧数: {video_frames}")
        
        frame_count = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # 如果需要调整尺寸
            if resize_to_first and (video_width != width or video_height != height):
                frame = cv2.resize(frame, (width, height))
            
            out.write(frame)
            frame_count += 1
            total_frames += 1
        
        cap.release()
        print(f"   ✅ 已写入 {frame_count} 帧")
    
    out.release()
    
    print(f"\n✅ 视频拼接完成: {output_path}")
    print(f"   总视频数: {len(video_paths)}")
    print(f"   总帧数: {total_frames}")
    print(f"   输出尺寸: {width}x{height}, FPS: {fps:.2f}")
    
    return output_path


def remove_background_from_image(
    image: Image.Image,
    method: str = "rembg",
    rembg_model: str = "u2net",
    removebg_api_key: str = None,
    rembg_session = None
) -> Image.Image:
    """
    从单张图片中去除背景
    
    Args:
        image: PIL Image 对象
        method: 去除方式 ("rembg" 或 "removebg")
        rembg_model: rembg 模型名称
        removebg_api_key: Remove.bg API Key
        rembg_session: rembg session（可选，复用以提高性能）
    
    Returns:
        去除背景后的 PIL Image（RGBA）
    """
    if method == "rembg":
        if not REMBG_AVAILABLE:
            raise RuntimeError("rembg 未安装，请运行 pip install rembg")
        
        # 使用传入的 session 或创建新的
        if rembg_session:
            result = rembg_remove(image, session=rembg_session)
        else:
            session = new_session(rembg_model)
            result = rembg_remove(image, session=session)
        
        return result
    
    elif method == "removebg":
        if not removebg_api_key:
            raise ValueError("使用 Remove.bg API 需要提供 API Key")
        
        # 将图片转换为字节
        img_byte_arr = io.BytesIO()
        image.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        # 调用 Remove.bg API
        response = requests.post(
            'https://api.remove.bg/v1.0/removebg',
            files={'image_file': img_byte_arr},
            data={'size': 'auto'},
            headers={'X-Api-Key': removebg_api_key},
        )
        
        if response.status_code == 200:
            return Image.open(io.BytesIO(response.content)).convert('RGBA')
        else:
            raise RuntimeError(f"Remove.bg API 错误: {response.status_code} - {response.text}")
    
    else:
        raise ValueError(f"不支持的去背景方式: {method}")


def convert_mp4_to_transparent_gif(
    input_path: str,
    output_path: str,
    method: str = "rembg",
    rembg_model: str = "u2net",
    removebg_api_key: str = None,
    fps_reduction: int = 2,
    max_width: int = 480,
    status_callback = None
) -> str:
    """
    将MP4转换为透明背景GIF（逐帧去背景）
    
    Args:
        input_path: 输入MP4路径
        output_path: 输出GIF路径
        method: 去背景方式 ("rembg" 或 "removebg")
        rembg_model: rembg 模型名称
        removebg_api_key: Remove.bg API Key
        fps_reduction: 帧率缩减倍数
        max_width: GIF最大宽度
        status_callback: 状态回调函数 (progress, message)
    
    Returns:
        输出GIF路径
    """
    cap = cv2.VideoCapture(input_path)
    
    if not cap.isOpened():
        raise Exception(f"无法打开视频: {input_path}")
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    # 计算需要处理的帧数
    frames_to_process = total_frames // fps_reduction
    
    # 计算缩放
    if width > max_width:
        scale_factor = max_width / width
        new_width = max_width
        new_height = int(height * scale_factor)
    else:
        new_width = width
        new_height = height
        scale_factor = 1.0
    
    # 创建 rembg session（复用以提高性能）
    rembg_session = None
    if method == "rembg" and REMBG_AVAILABLE:
        print(f"📦 加载 rembg 模型: {rembg_model}")
        rembg_session = new_session(rembg_model)
    
    # 读取并处理帧
    frames = []
    frame_count = 0
    processed_count = 0
    
    print(f"🎬 开始处理视频: {Path(input_path).name}")
    print(f"   总帧数: {total_frames}, 预计处理: {frames_to_process} 帧")
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        # 跳帧
        if frame_count % fps_reduction == 0:
            # BGR转RGB
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # 缩放
            if scale_factor != 1.0:
                frame_rgb = cv2.resize(frame_rgb, (new_width, new_height))
            
            # 转PIL Image
            pil_image = Image.fromarray(frame_rgb)
            
            # 去除背景
            try:
                transparent_image = remove_background_from_image(
                    pil_image,
                    method=method,
                    rembg_model=rembg_model,
                    removebg_api_key=removebg_api_key,
                    rembg_session=rembg_session
                )
                frames.append(transparent_image)
                processed_count += 1
                
                # 进度回调
                if status_callback and frames_to_process > 0:
                    progress = int((processed_count / frames_to_process) * 100)
                    status_callback(progress, f"处理帧 {processed_count}/{frames_to_process}")
                
                if processed_count % 10 == 0:
                    print(f"   ✅ 已处理 {processed_count}/{frames_to_process} 帧")
                    
            except Exception as e:
                print(f"   ⚠️ 帧 {processed_count} 去背景失败: {e}")
                # 失败时使用原图
                frames.append(pil_image.convert('RGBA'))
                processed_count += 1
        
        frame_count += 1
    
    cap.release()
    
    if not frames:
        raise Exception("没有读取到任何帧")
    
    # 计算GIF帧间隔
    gif_fps = fps / fps_reduction
    frame_duration = int(1000 / gif_fps)
    
    # 保存透明GIF
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    
    print(f"💾 保存透明GIF...")
    
    # 使用 dispose=2 确保透明度正确
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=frame_duration,
        loop=0,
        optimize=False,  # 透明GIF不优化以保持质量
        disposal=2,  # 每帧清除前一帧
        transparency=0
    )
    
    print(f"✅ 透明GIF已保存: {output_path}")
    print(f"   处理帧数: {len(frames)}")
    
    return output_path


def convert_gif_to_transparent_gif(
    input_path: str,
    output_path: str,
    method: str = "rembg",
    rembg_model: str = "u2net",
    removebg_api_key: str = None,
    status_callback = None
) -> str:
    """
    将普通GIF转换为透明背景GIF（逐帧去背景）
    
    Args:
        input_path: 输入GIF路径
        output_path: 输出GIF路径
        method: 去背景方式 ("rembg" 或 "removebg")
        rembg_model: rembg 模型名称
        removebg_api_key: Remove.bg API Key
        status_callback: 状态回调函数 (progress, message)
    
    Returns:
        输出GIF路径
    """
    # 打开GIF
    gif = Image.open(input_path)
    
    # 获取帧数和时长
    try:
        n_frames = gif.n_frames
    except AttributeError:
        n_frames = 1
    
    duration = gif.info.get('duration', 100)
    
    print(f"🎬 开始处理GIF: {Path(input_path).name}")
    print(f"   总帧数: {n_frames}")
    
    # 创建 rembg session
    rembg_session = None
    if method == "rembg" and REMBG_AVAILABLE:
        print(f"📦 加载 rembg 模型: {rembg_model}")
        rembg_session = new_session(rembg_model)
    
    # 处理每一帧
    frames = []
    
    for i in range(n_frames):
        gif.seek(i)
        frame = gif.convert('RGB')
        
        try:
            transparent_frame = remove_background_from_image(
                frame,
                method=method,
                rembg_model=rembg_model,
                removebg_api_key=removebg_api_key,
                rembg_session=rembg_session
            )
            frames.append(transparent_frame)
            
            # 进度回调
            if status_callback:
                progress = int(((i + 1) / n_frames) * 100)
                status_callback(progress, f"处理帧 {i + 1}/{n_frames}")
            
            if (i + 1) % 10 == 0:
                print(f"   ✅ 已处理 {i + 1}/{n_frames} 帧")
                
        except Exception as e:
            print(f"   ⚠️ 帧 {i + 1} 去背景失败: {e}")
            frames.append(frame.convert('RGBA'))
    
    if not frames:
        raise Exception("没有处理到任何帧")
    
    # 保存透明GIF
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    
    print(f"💾 保存透明GIF...")
    
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        optimize=False,
        disposal=2,
        transparency=0
    )
    
    print(f"✅ 透明GIF已保存: {output_path}")
    print(f"   处理帧数: {len(frames)}")
    
    return output_path

