#!/bin/bash

echo "🏆 开始下载最佳模型组合..."
echo "📊 总大小约: 40 GB"
echo "⏱️  预计时间: 2-4 小时（取决于网速）"
echo ""

# 安装 huggingface-cli
echo "📦 安装 huggingface-hub..."
pip install -U huggingface-hub

# 创建目录
mkdir -p models/flux
mkdir -p models/ip_adapter/flux
mkdir -p models/controlnet/flux-union
mkdir -p models/lora/flux-3d
mkdir -p models/pose_library

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 1/4 下载 Flux.1-dev 基础模型 (~23 GB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
huggingface-cli download black-forest-labs/FLUX.1-dev \
  --local-dir models/flux/flux-dev \
  --local-dir-use-symlinks False

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 2/4 下载 IP-Adapter for Flux (~5 GB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
huggingface-cli download InstantX/FLUX.1-dev-IP-Adapter \
  --local-dir models/ip_adapter/flux \
  --local-dir-use-symlinks False

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 3/4 下载 ControlNet Union for Flux (~6.5 GB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
huggingface-cli download InstantX/FLUX.1-dev-Controlnet-Union \
  --local-dir models/controlnet/flux-union \
  --local-dir-use-symlinks False

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 4/4 下载 3D Cartoon LoRA (~500 MB)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
huggingface-cli download alvdansen/flux-koda \
  --local-dir models/lora/flux-3d \
  --local-dir-use-symlinks False

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 所有模型下载完成！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 总大小: ~40 GB"
echo "📁 模型位置: backend/models/"
echo ""
echo "🎯 下一步: 运行 python verify_setup.py 验证安装"

