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
# 统一使用海外版 API (api.klingai.com)
# ============================================

# API 密钥（统一使用一套密钥）
KLING_ACCESS_KEY = os.getenv("KLING_ACCESS_KEY", "")
KLING_SECRET_KEY = os.getenv("KLING_SECRET_KEY", "")

# 视频生成 API 密钥（向后兼容，如果设置了视频密钥则使用，否则使用统一密钥）
KLING_VIDEO_ACCESS_KEY = os.getenv("KLING_VIDEO_ACCESS_KEY", "") or KLING_ACCESS_KEY
KLING_VIDEO_SECRET_KEY = os.getenv("KLING_VIDEO_SECRET_KEY", "") or KLING_SECRET_KEY

# 海外版API URL（图片和视频统一使用）
KLING_BASE_URL = os.getenv("KLING_BASE_URL", "https://api.klingai.com")
# 向后兼容旧的环境变量名
KLING_OVERSEAS_BASE_URL = os.getenv("KLING_OVERSEAS_BASE_URL", KLING_BASE_URL)

if not KLING_ACCESS_KEY or not KLING_SECRET_KEY:
    print("⚠️ 警告: 未设置可灵AI密钥环境变量 (KLING_ACCESS_KEY, KLING_SECRET_KEY)")
    print("   请在环境变量中设置，或在本地开发时使用 .env 文件")
else:
    print(f"✅ 可灵AI密钥已配置（使用海外版 API）")

# ============================================
# Google AI API 配置（用于图片内容审核）
# ============================================

# Google Gemini API密钥（可选，用于AI图片预处理）
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")

# 是否启用AI图片预处理（默认启用，如果有API Key）
ENABLE_AI_IMAGE_CHECK = os.getenv("ENABLE_AI_IMAGE_CHECK", "true").lower() in ("true", "1", "yes")

if GOOGLE_API_KEY and ENABLE_AI_IMAGE_CHECK:
    print(f"✅ Google AI图片检查已启用")
elif ENABLE_AI_IMAGE_CHECK and not GOOGLE_API_KEY:
    print("⚠️ 警告: 启用了AI图片检查但未设置 GOOGLE_API_KEY")
    print("   AI图片预处理功能将不可用")
    ENABLE_AI_IMAGE_CHECK = False
else:
    print("ℹ️ AI图片检查未启用（可通过 ENABLE_AI_IMAGE_CHECK=true 启用）")
