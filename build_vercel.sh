#!/bin/bash
set -e

echo "🚀 开始 Vercel Flutter 构建..."

# 安装 Flutter SDK
echo "📦 下载 Flutter SDK..."
FLUTTER_VERSION="3.24.0"
curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | tar xJ

# 设置 Flutter 路径
export PATH="$PWD/flutter/bin:$PATH"

# 验证 Flutter
echo "✅ Flutter 版本:"
flutter --version

# 获取依赖
echo "📦 获取依赖..."
flutter pub get

# 构建 Web
echo "🔨 构建 Flutter Web..."
flutter build web --release --web-renderer canvaskit \
  --dart-define=API_BASE_URL=${API_BASE_URL:-https://pet-motion-lab-api.up.railway.app}

echo "✅ 构建完成!"
ls -la build/web/

