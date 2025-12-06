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
            "docs": "/docs",
            "health": "/health"
        }
    }


@app.get("/health")
async def health_check():
    """健康检查"""
    import sys
    import os
    import database as db
    
    # 检查数据库状态
    db_status = "unknown"
    db_type = "unknown"
    db_error = None
    
    try:
        # 尝试查询数据库
        tasks, total = db.get_all_tasks(page=1, page_size=1)
        db_status = "connected"
        db_type = "turso" if db.USE_TURSO else "local_sqlite"
    except Exception as e:
        db_status = "error"
        db_error = str(e)
    
    return {
        "status": "healthy",
        "python_version": sys.version,
        "api_version": "2.0.0",
        "mode": "kling_only",
        "database": {
            "status": db_status,
            "type": db_type,
            "use_turso": db.USE_TURSO,
            "turso_url_set": bool(os.environ.get("TURSO_DATABASE_URL")),
            "turso_token_set": bool(os.environ.get("TURSO_AUTH_TOKEN")),
            "error": db_error
        },
        "services": {
            "kling_ai": "available",
            "background_removal": "available",
            "flux_models": "disabled"
        }
    }


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

