#!/usr/bin/env python3
"""
Google API 验证脚本
快速验证 Google Gemini API 是否可用
"""

import os
import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

def verify_google_api():
    """验证 Google API 是否可用"""
    print("=" * 60)
    print("🔍 Google API 验证")
    print("=" * 60)
    
    # 步骤1: 加载配置
    print("\n📋 步骤 1: 检查配置")
    try:
        from config import GOOGLE_API_KEY
        if GOOGLE_API_KEY:
            # 只显示前8位和后4位
            masked_key = GOOGLE_API_KEY[:8] + "..." + GOOGLE_API_KEY[-4:] if len(GOOGLE_API_KEY) > 12 else "***"
            print(f"   ✅ GOOGLE_API_KEY 已设置: {masked_key}")
        else:
            print("   ❌ GOOGLE_API_KEY 未设置")
            print("   请在 backend/.env 文件中设置 GOOGLE_API_KEY")
            return False
    except Exception as e:
        print(f"   ❌ 配置加载失败: {e}")
        return False
    
    # 步骤2: 检查依赖
    print("\n📦 步骤 2: 检查依赖")
    try:
        import google.generativeai as genai
        print("   ✅ google-generativeai 已安装")
    except ImportError:
        print("   ❌ google-generativeai 未安装")
        print("   请运行: pip install google-generativeai")
        return False
    
    try:
        from PIL import Image
        print("   ✅ Pillow 已安装")
    except ImportError:
        print("   ❌ Pillow 未安装")
        print("   请运行: pip install Pillow")
        return False
    
    # 步骤3: 初始化 API
    print("\n🔧 步骤 3: 初始化 Gemini API")
    try:
        genai.configure(api_key=GOOGLE_API_KEY)
        model = genai.GenerativeModel('gemini-2.5-flash-lite')
        print("   ✅ API 初始化成功")
        print(f"   模型: gemini-2.5-flash-lite (免费配额: 15 RPM, 1000 RPD)")
    except Exception as e:
        print(f"   ❌ API 初始化失败: {e}")
        return False
    
    # 步骤4: 简单文本测试
    print("\n💬 步骤 4: 文本生成测试")
    try:
        response = model.generate_content("Say 'Hello, the API is working!' in one line.")
        print(f"   ✅ API 响应成功")
        print(f"   回复: {response.text.strip()}")
    except Exception as e:
        print(f"   ❌ 文本生成失败: {e}")
        if "API_KEY_INVALID" in str(e):
            print("   原因: API 密钥无效")
        elif "quota" in str(e).lower():
            print("   原因: API 配额已用尽")
        elif "permission" in str(e).lower():
            print("   原因: 没有权限使用此 API")
        return False
    
    # 步骤5: 图片分析测试
    print("\n🖼️ 步骤 5: 图片分析测试")
    
    # 查找测试图片
    test_image_path = project_root.parent / "assets" / "images" / "golden_retriever_sit_front.jpg"
    if not test_image_path.exists():
        # 尝试其他图片
        images_dir = project_root.parent / "assets" / "images"
        if images_dir.exists():
            for img in images_dir.iterdir():
                if img.suffix.lower() in ['.jpg', '.jpeg', '.png']:
                    test_image_path = img
                    break
    
    if not test_image_path.exists():
        print(f"   ⚠️ 未找到测试图片，跳过图片测试")
        print(f"   尝试的路径: {test_image_path}")
    else:
        print(f"   测试图片: {test_image_path.name}")
        try:
            img = Image.open(test_image_path)
            response = model.generate_content([
                "Describe this image in one sentence. What animal do you see?",
                img
            ])
            print(f"   ✅ 图片分析成功")
            print(f"   回复: {response.text.strip()}")
        except Exception as e:
            print(f"   ❌ 图片分析失败: {e}")
            return False
    
    # 总结
    print("\n" + "=" * 60)
    print("🎉 验证完成！Google API 工作正常！")
    print("=" * 60)
    return True


if __name__ == "__main__":
    success = verify_google_api()
    sys.exit(0 if success else 1)

