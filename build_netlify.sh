#!/bin/bash
set -e

echo "🚀 Netlify Flutter 构建开始..."

# Flutter 版本
FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.0}"

# 检查是否已缓存 Flutter
if [ ! -d "flutter" ]; then
  echo "📦 下载 Flutter SDK v${FLUTTER_VERSION}..."
  curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | tar xJ
else
  echo "✅ 使用缓存的 Flutter SDK"
fi

# 设置 Flutter 路径
export PATH="$PWD/flutter/bin:$PATH"

# 禁用 Flutter 分析
flutter config --no-analytics

# 显示 Flutter 版本
echo "📱 Flutter 版本:"
flutter --version

# 获取依赖
echo "📦 获取项目依赖..."
flutter pub get

# 构建 Web 应用
echo "🔨 构建 Flutter Web..."
flutter build web --release --web-renderer canvaskit \
  --dart-define=API_BASE_URL=${API_BASE_URL:-https://pet-motion-lab-api.up.railway.app}

echo "✅ 构建完成!"
echo "📁 输出目录内容:"
ls -la build/web/

