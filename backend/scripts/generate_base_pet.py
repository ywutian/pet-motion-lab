#!/usr/bin/env python3
"""
生成第一张图片 - 纯3D卡通宠物品种图
使用 Stability AI API 生成卡通3D宠物品种名称字猫/犬
背景纯白色，坐姿，高分辨率
"""

import requests
import base64
from PIL import Image
from pathlib import Path
import io
import time
import argparse


# Stability API 配置
STABILITY_API_KEY = "sk-P4kJrrl0LC3I0Skpy6QGRNuiimQogHs9gmDwJpj3XnMaje8c"
STABILITY_API_HOST = "https://api.stability.ai"


def generate_base_pet_image(
    species: str = "cat",  # cat 或 dog
    breed: str = "ragdoll",  # 品种名称，如 ragdoll, golden_retriever
    output_dir: str = "output/base_pets",
    seed: int = None,
):
    """
    生成第一张图片：纯3D卡通宠物品种图
    
    Args:
        species: 物种 (cat/dog)
        breed: 品种名称
        output_dir: 输出目录
        seed: 随机种子
    
    Returns:
        生成的图片路径
    """
    print("=" * 70)
    print("🎨 生成第一张图片 - 3D卡通宠物品种图")
    print("=" * 70)
    print()
    
    # 创建输出目录
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # 构建提示词
    species_name = "cat" if species == "cat" else "dog"
    breed_name = breed.replace("_", " ")
    
    prompt = (
        f"3D cartoon render of a {breed_name} {species_name}, "
        f"Pixar style, Disney quality, toon shading, "
        f"sitting pose, front view, "
        f"pure white background #FFFFFF, "
        f"clean colors, smooth surface, no shadows, "
        f"cute and friendly expression, warm and welcoming, "
        f"high resolution, professional 3D modeling, "
        f"centered composition, studio lighting"
    )
    
    negative_prompt = (
        "realistic, photorealistic, real fur texture, "
        "side view, back view, "
        "background elements, shadows, floor, ground, "
        "膨子, accessories, collar, "
        "ugly, deformed, blurry, bad anatomy, "
        "multiple animals, cropped, "
        "low quality, low resolution"
    )
    
    print(f"🐾 物种: {species_name}")
    print(f"🏷️  品种: {breed_name}")
    print(f"📝 Prompt: {prompt}")
    print()
    
    # 调用 Stability API
    url = f"{STABILITY_API_HOST}/v2beta/stable-image/generate/sd3"
    
    headers = {
        "authorization": f"Bearer {STABILITY_API_KEY}",
        "accept": "image/*"
    }
    
    data = {
        "prompt": prompt,
        "negative_prompt": negative_prompt,
        "mode": "text-to-image",
        "aspect_ratio": "1:1",  # 正方形，适合后续裁剪
        "output_format": "png",
    }
    
    if seed is not None:
        data["seed"] = seed
    
    print("🚀 发送请求到 Stability API...")
    start_time = time.time()
    
    try:
        response = requests.post(
            url,
            headers=headers,
            data=data,
            timeout=60
        )
        
        request_time = time.time() - start_time
        
        if response.status_code == 200:
            print(f"✅ 生成成功! 耗时: {request_time:.1f}s")
            print()
            
            # 保存图片
            output_file = output_path / f"{species}_{breed}_base.png"
            with open(output_file, "wb") as f:
                f.write(response.content)
            
            print(f"✅ 图片已保存: {output_file}")
            print()
            print("=" * 70)
            print("🎉 第一张图片生成完成!")
            print("=" * 70)
            print(f"📁 文件位置: {output_file}")
            print(f"💡 提示: 打开图片查看效果!")
            print(f"   open {output_file}")
            print("=" * 70)
            
            return str(output_file)
        
        else:
            print(f"❌ 生成失败!")
            print(f"状态码: {response.status_code}")
            print(f"错误信息: {response.text}")
            return None
    
    except Exception as e:
        print(f"❌ 发生错误: {e}")
        import traceback
        traceback.print_exc()
        return None


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="生成第一张图片 - 3D卡通宠物品种图")
    parser.add_argument("--species", type=str, default="cat", choices=["cat", "dog"], help="物种 (cat/dog)")
    parser.add_argument("--breed", type=str, default="ragdoll", help="品种名称")
    parser.add_argument("--output", type=str, default="output/base_pets", help="输出目录")
    parser.add_argument("--seed", type=int, default=None, help="随机种子")
    
    args = parser.parse_args()
    
    generate_base_pet_image(
        species=args.species,
        breed=args.breed,
        output_dir=args.output,
        seed=args.seed,
    )


if __name__ == "__main__":
    main()

