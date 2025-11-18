#!/bin/bash
# 启动后端服务器（完整版本 - 包含 Flux 模型）

echo "🚀 启动 Pet Motion Lab 后端服务器（完整版本）"
echo "================================================"

# 进入 backend 目录
cd backend

# 检查虚拟环境是否存在
if [ ! -d "venv" ]; then
    echo "📦 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "🔧 激活虚拟环境..."
source venv/bin/activate

# 检查是否需要安装依赖
if ! python -c "import fastapi" 2>/dev/null; then
    echo "📥 安装依赖（这可能需要几分钟）..."
    pip install -r requirements.txt
fi

# 启动服务器
echo ""
echo "✅ 启动服务器..."
echo "================================================"
python main.py

