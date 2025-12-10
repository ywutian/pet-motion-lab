#!/usr/bin/env python3
"""
图片处理工具函数
"""

import os
from pathlib import Path
from PIL import Image
import numpy as np


def remove_background(
    input_path: str, 
    output_path: str, 
    api_key: str = None,
    fill_white_background: bool = True,
    keep_transparent_copy: bool = True
) -> str:
    """
    去除图片背景，生成PNG（使用 Remove.bg API）

    Args:
        input_path: 输入图片路径
        output_path: 输出PNG路径
        api_key: Remove.bg API Key（可选，从环境变量读取）
        fill_white_background: 是否自动填充白色背景（默认True）
        keep_transparent_copy: 是否保留透明背景版本（默认True）

    Returns:
        输出文件路径（白色背景版本，如果 fill_white_background=True）
    """
    import requests

    if not os.path.exists(input_path):
        raise FileNotFoundError(f"输入文件不存在: {input_path}")

    # 获取 API Key
    if api_key is None:
        api_key = os.getenv("REMOVE_BG_API_KEY", "VHghMwshxpgnUnJhdsUDM93r")

    if not api_key or api_key == "your_api_key_here":
        raise ValueError("Remove.bg API Key 未配置。请设置 REMOVE_BG_API_KEY 环境变量")

    # 读取图片
    with open(input_path, 'rb') as f:
        input_data = f.read()

    # 调用 Remove.bg API
    response = requests.post(
        'https://api.remove.bg/v1.0/removebg',
        files={'image_file': input_data},
        data={'size': 'auto'},
        headers={'X-Api-Key': api_key},
        timeout=30
    )

    if response.status_code != 200:
        error_msg = response.json() if response.headers.get('content-type') == 'application/json' else response.text
        raise Exception(f"Remove.bg API 错误: {response.status_code} - {error_msg}")

    # 保存透明背景版本
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    
    # 如果需要保留透明版本，先保存为 _transparent.png
    if fill_white_background and keep_transparent_copy:
        # 保存透明版本
        transparent_path = output_path.replace('.png', '_transparent.png')
        with open(transparent_path, 'wb') as f:
            f.write(response.content)
        print(f"✅ 透明背景版本已保存: {transparent_path}")
        
        # 加载透明图片并添加白色背景
        img = Image.open(transparent_path)
        if img.mode == 'RGBA':
            # 创建白色背景
            white_bg = Image.new('RGB', img.size, (255, 255, 255))
            white_bg.paste(img, (0, 0), img)
            white_bg.save(output_path, 'PNG')
            print(f"✅ 白色背景版本已保存: {output_path}")
        else:
            # 如果没有透明通道，直接保存
            with open(output_path, 'wb') as f:
                f.write(response.content)
    elif fill_white_background:
        # 只保存白色背景版本
        with open(output_path, 'wb') as f:
            f.write(response.content)
        # 添加白色背景
        add_white_background(output_path, output_path)
        print(f"✅ 白色背景版本已保存: {output_path}")
    else:
        # 只保存透明版本
        with open(output_path, 'wb') as f:
            f.write(response.content)
        print(f"✅ 去背景完成（透明背景）: {output_path}")

    return output_path


def add_white_background(input_path: str, output_path: str = None) -> str:
    """
    为透明背景图片添加白色背景
    
    Args:
        input_path: 输入图片路径（PNG格式，带透明背景）
        output_path: 输出图片路径（默认覆盖原文件）
    
    Returns:
        输出文件路径
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"输入文件不存在: {input_path}")
    
    if output_path is None:
        output_path = input_path
    
    # 打开图片
    img = Image.open(input_path)
    
    # 如果图片没有透明通道，直接返回
    if img.mode != 'RGBA':
        print(f"ℹ️ 图片没有透明通道，跳过白色背景填充")
        return input_path
    
    # 创建白色背景
    white_bg = Image.new('RGBA', img.size, (255, 255, 255, 255))
    
    # 将原图粘贴到白色背景上（使用alpha通道作为蒙版）
    white_bg.paste(img, (0, 0), img)
    
    # 转换为RGB模式（去除alpha通道）
    result = white_bg.convert('RGB')
    
    # 保存
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    result.save(output_path, 'PNG')
    
    return output_path


def add_white_background_keep_transparent(input_path: str, output_path: str = None) -> str:
    """
    为透明背景图片添加白色背景，但保留透明PNG格式
    （用于需要保留透明度信息的场景）
    
    Args:
        input_path: 输入图片路径（PNG格式，带透明背景）
        output_path: 输出图片路径（默认覆盖原文件）
    
    Returns:
        输出文件路径
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"输入文件不存在: {input_path}")
    
    if output_path is None:
        output_path = input_path
    
    # 打开图片
    img = Image.open(input_path)
    
    # 如果图片没有透明通道，直接返回
    if img.mode != 'RGBA':
        print(f"ℹ️ 图片没有透明通道，跳过白色背景填充")
        return input_path
    
    # 创建白色背景
    white_bg = Image.new('RGBA', img.size, (255, 255, 255, 255))
    
    # 将原图粘贴到白色背景上
    white_bg.paste(img, (0, 0), img)
    
    # 保存为PNG（保留RGBA格式）
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    white_bg.save(output_path, 'PNG')
    
    return output_path


def resize_image(input_path: str, output_path: str, size: tuple) -> str:
    """
    调整图片尺寸
    
    Args:
        input_path: 输入图片路径
        output_path: 输出图片路径
        size: 目标尺寸 (width, height)
    
    Returns:
        输出文件路径
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"输入文件不存在: {input_path}")
    
    img = Image.open(input_path)
    img_resized = img.resize(size, Image.Resampling.LANCZOS)
    
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    img_resized.save(output_path)
    
    print(f"✅ 图片已调整尺寸: {output_path} ({size[0]}x{size[1]})")
    return output_path


def ensure_square(input_path: str, output_path: str, size: int = 1024) -> str:
    """
    确保图片为正方形
    
    Args:
        input_path: 输入图片路径
        output_path: 输出图片路径
        size: 正方形边长
    
    Returns:
        输出文件路径
    """
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"输入文件不存在: {input_path}")
    
    img = Image.open(input_path)
    
    # 如果已经是正方形，直接调整尺寸
    if img.width == img.height:
        return resize_image(input_path, output_path, (size, size))
    
    # 创建正方形画布（白色背景）
    canvas_size = max(img.width, img.height)
    canvas = Image.new('RGB', (canvas_size, canvas_size), (255, 255, 255))
    
    # 居中粘贴
    offset_x = (canvas_size - img.width) // 2
    offset_y = (canvas_size - img.height) // 2
    
    if img.mode == 'RGBA':
        canvas.paste(img, (offset_x, offset_y), img)
    else:
        canvas.paste(img, (offset_x, offset_y))
    
    # 调整到目标尺寸
    canvas_resized = canvas.resize((size, size), Image.Resampling.LANCZOS)
    
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    canvas_resized.save(output_path)
    
    print(f"✅ 图片已转为正方形: {output_path} ({size}x{size})")
    return output_path


def get_image_info(image_path: str) -> dict:
    """
    获取图片信息
    
    Returns:
        包含width, height, mode, format的字典
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"图片文件不存在: {image_path}")
    
    img = Image.open(image_path)
    
    return {
        "width": img.width,
        "height": img.height,
        "mode": img.mode,
        "format": img.format,
    }


if __name__ == "__main__":
    # 测试
    print("图片处理工具测试")
    print("=" * 50)
    
    # 这里可以添加测试代码
    pass

