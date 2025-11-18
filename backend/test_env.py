#!/usr/bin/env python3
"""
测试环境变量配置
"""
import os
from pathlib import Path

# 尝试加载 .env 文件（如果存在）
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        print(f"✅ 已加载 .env 文件: {env_path}")
    else:
        print(f"⚠️  .env 文件不存在: {env_path}")
except ImportError:
    print("⚠️  python-dotenv 未安装，跳过 .env 文件加载")
    print("   提示: pip install python-dotenv")

# 读取环境变量
from config import KLING_ACCESS_KEY, KLING_SECRET_KEY

print("\n" + "=" * 60)
print("🔐 环境变量配置测试")
print("=" * 60)

if KLING_ACCESS_KEY and KLING_SECRET_KEY:
    print("✅ 可灵AI密钥配置成功！")
    print(f"   Access Key: {KLING_ACCESS_KEY[:10]}...{KLING_ACCESS_KEY[-10:]}")
    print(f"   Secret Key: {KLING_SECRET_KEY[:10]}...{KLING_SECRET_KEY[-10:]}")
else:
    print("❌ 可灵AI密钥未配置！")
    print("   请设置环境变量:")
    print("   - KLING_ACCESS_KEY")
    print("   - KLING_SECRET_KEY")
    print()
    print("   或创建 .env 文件:")
    print("   cp .env.example .env")
    print("   然后编辑 .env 文件填入密钥")

print("=" * 60)

