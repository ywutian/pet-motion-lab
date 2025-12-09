#!/usr/bin/env python3
"""
Pet Motion Lab - 后端服务器（仅可灵AI）
轻量级版本，不加载本地Flux模型
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import uvicorn

from api.kling_generation import router as kling_router
from api.kling_tools import router as kling_tools_router
from api.background_removal import router as background_router
from api.video_trimming import router as video_router
from api.model_test import router as model_test_router

# 创建 FastAPI 应用
app = FastAPI(
    title="Pet Motion Lab API (Kling AI Only)",
    description="基于可灵AI的宠物动画生成服务",
    version="2.0.0"
)

# 配置 CORS（允许 Flutter 前端访问）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应该限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(kling_router)  # 可灵AI生成
app.include_router(kling_tools_router)  # 可灵AI工具
app.include_router(background_router)  # 背景去除
app.include_router(video_router)  # 视频裁剪
app.include_router(model_test_router)  # 模型测试

# 静态文件服务（用于访问生成的图片）
output_dir = Path("output")
output_dir.mkdir(exist_ok=True)
app.mount("/output", StaticFiles(directory="output"), name="output")


@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "Pet Motion Lab API (Kling AI Only)",
        "version": "2.0.0",
        "status": "running",
        "mode": "kling_only",
        "endpoints": {
            "kling_generate": "/api/kling/generate",
            "kling_status": "/api/kling/status/{pet_id}",
            "kling_results": "/api/kling/results/{pet_id}",
            "kling_image_to_image": "/api/kling/tools/image-to-image",
            "kling_image_to_video": "/api/kling/tools/image-to-video",
            "kling_frames_to_video": "/api/kling/tools/frames-to-video",
            "background_remove": "/api/background/remove",
            "video_info": "/api/video/info",
            "video_trim": "/api/video/trim",
            "video_extract_frame": "/api/video/extract-frame",
            "model_test_list": "/api/kling/model-test/models",
            "model_test_video": "/api/kling/model-test/test-video-model",
            "model_test_image": "/api/kling/model-test/test-image-model",
            "docs": "/docs",
            "health": "/health"
        }
    }


@app.get("/health")
async def health_check():
    """健康检查"""
    import sys
    from config import (
        KLING_ACCESS_KEY,
        KLING_SECRET_KEY,
        KLING_VIDEO_ACCESS_KEY,
        KLING_VIDEO_SECRET_KEY,
        KLING_OVERSEAS_BASE_URL,
    )

    return {
        "status": "healthy",
        "python_version": sys.version,
        "api_version": "2.0.0",
        "mode": "kling_only",
        "services": {
            "kling_ai": "available",
            "background_removal": "available",
            "flux_models": "disabled"
        },
        "api_endpoints": {
            "image_api": "https://api-beijing.klingai.com",
            "video_api": KLING_OVERSEAS_BASE_URL
        },
        "api_keys": {
            "image_access_key": f"{KLING_ACCESS_KEY[:8]}..." if KLING_ACCESS_KEY else "NOT_SET",
            "image_secret_key": f"{KLING_SECRET_KEY[:8]}..." if KLING_SECRET_KEY else "NOT_SET",
            "video_access_key": f"{KLING_VIDEO_ACCESS_KEY[:8]}..." if KLING_VIDEO_ACCESS_KEY else "NOT_SET",
            "video_secret_key": f"{KLING_VIDEO_SECRET_KEY[:8]}..." if KLING_VIDEO_SECRET_KEY else "NOT_SET",
        }
    }


@app.get("/test-api-keys")
async def test_api_keys():
    """测试 API 密钥是否有效（通过调用可灵 AI 的账户接口）"""
    import requests
    import jwt
    import time
    from config import (
        KLING_ACCESS_KEY,
        KLING_SECRET_KEY,
        KLING_VIDEO_ACCESS_KEY,
        KLING_VIDEO_SECRET_KEY,
    )

    def test_key(access_key: str, secret_key: str, name: str) -> dict:
        """测试单个密钥对"""
        if not access_key or not secret_key:
            return {"name": name, "status": "NOT_CONFIGURED", "error": "密钥未设置"}

        try:
            # 生成 JWT Token
            headers = {"alg": "HS256", "typ": "JWT"}
            payload = {
                "iss": access_key,
                "exp": int(time.time()) + 1800,
                "nbf": int(time.time()) - 5
            }
            token = jwt.encode(payload, secret_key, headers=headers)

            # 尝试调用一个简单的 API（查询任务列表）
            test_url = "https://api-beijing.klingai.com/v1/images/generations"
            auth_headers = {
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {token}'
            }

            # 发送一个空的 GET 请求来测试认证
            # 注意：这里用 GET 请求查询，不会消耗额度
            response = requests.get(
                "https://api-beijing.klingai.com/v1/images/generations/test-invalid-id",
                headers=auth_headers,
                timeout=10
            )

            # 401 = 认证失败，404 = 认证成功但任务不存在（这是我们期望的）
            if response.status_code == 404:
                return {
                    "name": name,
                    "status": "VALID",
                    "access_key": f"{access_key[:8]}...",
                    "message": "密钥有效"
                }
            elif response.status_code == 401:
                error_data = response.json() if response.text else {}
                return {
                    "name": name,
                    "status": "INVALID",
                    "access_key": f"{access_key[:8]}...",
                    "error": error_data.get("message", response.text),
                    "code": error_data.get("code")
                }
            else:
                return {
                    "name": name,
                    "status": "UNKNOWN",
                    "access_key": f"{access_key[:8]}...",
                    "http_code": response.status_code,
                    "response": response.text[:200]
                }

        except Exception as e:
            return {
                "name": name,
                "status": "ERROR",
                "error": str(e)
            }

    # 测试两组密钥
    results = {
        "image_api": test_key(KLING_ACCESS_KEY, KLING_SECRET_KEY, "图片API"),
        "video_api": test_key(KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY, "视频API"),
    }

    # 检查两组密钥是否相同
    if KLING_ACCESS_KEY == KLING_VIDEO_ACCESS_KEY and KLING_SECRET_KEY == KLING_VIDEO_SECRET_KEY:
        results["note"] = "图片API和视频API使用相同的密钥"
    else:
        results["note"] = "图片API和视频API使用不同的密钥"

    return results


if __name__ == "__main__":
    import os

    # 从环境变量获取端口（Render 会设置 PORT 环境变量）
    port = int(os.environ.get("PORT", 8002))

    print("=" * 70)
    print("🚀 Pet Motion Lab - 后端服务器 v2.0 (仅可灵AI)")
    print("=" * 70)
    print()
    print(f"📚 API 文档: http://localhost:{port}/docs")
    print(f"🏥 健康检查: http://localhost:{port}/health")
    print()
    print("🎨 可灵AI生成接口:")
    print("  - 生成动画: POST /api/kling/generate")
    print("  - 查询状态: GET /api/kling/status/{pet_id}")
    print("  - 获取结果: GET /api/kling/results/{pet_id}")
    print()
    print("🖼️  背景去除接口:")
    print("  - 去除背景: POST /api/background/remove")
    print()
    print("🎬 视频裁剪接口:")
    print("  - 获取视频信息: POST /api/video/info")
    print("  - 裁剪视频: POST /api/video/trim")
    print()
    print("💡 提示: 此版本不加载Flux模型，仅保留背景去除和视频裁剪功能！")
    print()
    print("=" * 70)
    print()

    # 启动服务器
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=port,
        log_level="info"
    )

