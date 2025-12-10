#!/usr/bin/env python3
"""快速测试 Google Gemini API 是否正常工作"""

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

    print("🤖 创建模型...")
    model = genai.GenerativeModel('gemini-1.5-flash')

    print("💬 测试文本生成...")
    response = model.generate_content("Say 'Hello! I am Gemini 2.0 Flash.' in one short sentence.")

    print("\n✅ 测试成功！")
    print(f"📝 Gemini 响应: {response.text}")
    print("\n🎉 AI图片检查功能已就绪，可以正常使用！")

except Exception as e:
    print(f"\n❌ 测试失败: {e}")
    import traceback
    traceback.print_exc()
