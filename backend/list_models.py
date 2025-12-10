#!/usr/bin/env python3
"""列出可用的 Gemini 模型"""

import sys
from pathlib import Path

# 添加项目路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "backend"))

from backend.config import GOOGLE_API_KEY

try:
    import google.generativeai as genai

    print("🔧 配置 Gemini API...")
    genai.configure(api_key=GOOGLE_API_KEY)

    print("\n📋 列出所有可用的模型:\n")

    for model in genai.list_models():
        if 'generateContent' in model.supported_generation_methods:
            print(f"✅ {model.name}")
            print(f"   描述: {model.display_name}")
            print(f"   支持的方法: {', '.join(model.supported_generation_methods)}")
            print()

except Exception as e:
    print(f"\n❌ 错误: {e}")
    import traceback
    traceback.print_exc()
