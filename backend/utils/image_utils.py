#!/usr/bin/env python3
"""
图片处理工具函数
"""

import os
from pathlib import Path
from PIL import Image
import numpy as np


def remove_background(input_path: str, output_path: str, api_key: str = None) -> str:
    """
    去除图片背景，生成透明PNG（使用 Remove.bg API）

    Args:
        input_path: 输入图片路径
        output_path: 输出PNG路径
        api_key: Remove.bg API Key（可选，从环境变量读取）

    Returns:
        输出文件路径
    """
    import requests

    if not os.path.exists(input_path):
        raise FileNotFoundError(f"输入文件不存在: {input_path}")

    # 获取 API Key
    if api_key is None:
        api_key = os.getenv("REMOVE_BG_API_KEY", "u7do7iuW3gtQjSg2Qx93RiWH")

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

    # 保存
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(response.content)

    print(f"✅ 去背景完成: {output_path}")
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

