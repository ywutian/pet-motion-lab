#!/usr/bin/env python3
"""
Rembg 服务包装器
用于从 Flutter/Dart 调用 rembg 进行背景移除
"""

import sys
import json
import base64
from pathlib import Path

try:
    from rembg import remove, new_session
    from PIL import Image
    import io
except ImportError as e:
    print(json.dumps({"error": f"导入失败: {e}. 请安装: pip install rembg[new] pillow"}))
    sys.exit(1)


def remove_background(input_path, output_path, model_name="u2net"):
    """
    移除图片背景
    
    Args:
        input_path: 输入图片路径
        output_path: 输出图片路径
        model_name: 模型名称 (u2net, u2netp, u2net_human_seg, silueta, isnet-general-use, isnet-anime, birefnet-general, etc.)
    
    Returns:
        dict: 包含成功状态和信息的字典
    """
    try:
        # 创建会话（可选，用于性能优化）
        session = new_session(model_name)
        
        # 读取输入图片
        with open(input_path, 'rb') as input_file:
            input_data = input_file.read()
        
        # 移除背景
        output_data = remove(input_data, session=session)
        
        # 保存输出图片
        output_path_obj = Path(output_path)
        output_path_obj.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'wb') as output_file:
            output_file.write(output_data)
        
        # 获取输出图片信息
        output_image = Image.open(io.BytesIO(output_data))
        width, height = output_image.size
        
        # 计算透明度统计
        if output_image.mode == 'RGBA':
            alpha_channel = output_image.split()[3]
            transparent_pixels = sum(1 for pixel in alpha_channel.getdata() if pixel == 0)
            total_pixels = width * height
            transparency_ratio = (transparent_pixels / total_pixels) * 100
        else:
            transparency_ratio = 0.0
        
        return {
            "success": True,
            "output_path": output_path,
            "width": width,
            "height": height,
            "transparency_ratio": round(transparency_ratio, 2),
            "model": model_name
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


def main():
    """命令行接口"""
    if len(sys.argv) < 4:
        print(json.dumps({
            "error": "用法: rembg_service.py <input_path> <output_path> <model_name>"
        }))
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    model_name = sys.argv[3] if len(sys.argv) > 3 else "u2net"
    
    result = remove_background(input_path, output_path, model_name)
    print(json.dumps(result, ensure_ascii=False))
    
    sys.exit(0 if result["success"] else 1)


if __name__ == "__main__":
    main()


