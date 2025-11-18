#!/bin/bash
# 启动后端服务器（仅可灵AI - 轻量级版本）

echo "🚀 启动 Pet Motion Lab 后端服务器（可灵AI版本）"
echo "================================================"

# 进入 backend 目录
cd backend

# 检查虚拟环境是否存在
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境（使用 Python 3.13）..."
    /opt/homebrew/bin/python3.13 -m venv venv
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 检查是否需要安装依赖
if ! python -c "import fastapi" 2>/dev/null; then
    echo "📥 安装依赖..."
    pip install fastapi uvicorn[standard] python-multipart rembg pyjwt pillow requests pydantic
fi

# 启动服务器
echo ""
echo "✅ 启动服务器..."
echo "================================================"
python main_kling_only.py

