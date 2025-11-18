#!/usr/bin/env python3
"""
Pet Motion Lab - 后端服务器
Flux + IP-Adapter + ControlNet 图像生成服务
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path
import uvicorn

from api.image_generation import router as generation_router
from api.kling_generation import router as kling_router
from api.kling_tools import router as kling_tools_router

# 创建 FastAPI 应用
app = FastAPI(
    title="Pet Motion Lab API",
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
app.include_router(generation_router)
app.include_router(kling_router)
app.include_router(kling_tools_router)

# 静态文件服务（用于访问生成的图片）
output_dir = Path("output")
output_dir.mkdir(exist_ok=True)
app.mount("/output", StaticFiles(directory="output"), name="output")


@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "Pet Motion Lab API",
        "version": "2.0.0",
        "status": "running",
        "endpoints": {
            "kling_generate": "/api/kling/generate",
            "kling_status": "/api/kling/status/{pet_id}",
            "kling_results": "/api/kling/results/{pet_id}",
            "generate_single": "/api/generate/single",
            "generate_batch": "/api/generate/batch",
            "docs": "/docs",
        }
    }


@app.get("/health")
async def health_check():
    """健康检查"""
    import sys

    return {
        "status": "healthy",
        "python_version": sys.version,
        "api_version": "2.0.0",
        "services": {
            "kling_ai": "available",
            "local_models": "optional"
        }
    }


if __name__ == "__main__":
    print("=" * 70)
    print("🚀 Pet Motion Lab - 后端服务器 v2.0")
    print("=" * 70)
    print()
    print("📚 API 文档: http://localhost:8000/docs")
    print("🏥 健康检查: http://localhost:8000/health")
    print()
    print("🎨 可灵AI生成接口:")
    print("  - 生成动画: POST /api/kling/generate")
    print("  - 查询状态: GET /api/kling/status/{pet_id}")
    print("  - 获取结果: GET /api/kling/results/{pet_id}")
    print()
    print("🎨 本地模型接口:")
    print("  - 单张图片: POST /api/generate/single")
    print("  - 批量生成: POST /api/generate/batch")
    print()
    print("=" * 70)
    print()

    # 启动服务器
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )

