import os
from pathlib import Path

# ============================================
# 加载 .env 文件（本地开发用）
# ============================================
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        print(f"✅ 已加载 .env 文件")
except ImportError:
    # 生产环境不需要 python-dotenv
    pass

# ============================================
# 可灵AI API 配置（从环境变量读取）
# ============================================

# 图片生成 API 密钥
KLING_ACCESS_KEY = os.getenv("KLING_ACCESS_KEY", "")
KLING_SECRET_KEY = os.getenv("KLING_SECRET_KEY", "")

# 视频生成 API 密钥（独立账户）
KLING_VIDEO_ACCESS_KEY = os.getenv("KLING_VIDEO_ACCESS_KEY", "")
KLING_VIDEO_SECRET_KEY = os.getenv("KLING_VIDEO_SECRET_KEY", "")

if not KLING_ACCESS_KEY or not KLING_SECRET_KEY:
    print("⚠️ 警告: 未设置可灵AI图片密钥环境变量 (KLING_ACCESS_KEY, KLING_SECRET_KEY)")
    print("   请在环境变量中设置，或在本地开发时使用 .env 文件")
else:
    print(f"✅ 可灵AI图片密钥已配置")

if not KLING_VIDEO_ACCESS_KEY or not KLING_VIDEO_SECRET_KEY:
    print("⚠️ 警告: 未设置可灵AI视频密钥环境变量 (KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY)")
    print("   请在环境变量中设置，或在本地开发时使用 .env 文件")
else:
    print(f"✅ 可灵AI视频密钥已配置")
