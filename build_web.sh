#!/bin/bash
# Flutter Web 构建脚本（用于部署）

echo "🚀 开始构建 Flutter Web..."
echo "================================"

# 设置 API 地址（从环境变量读取，或使用默认值）
API_URL="${API_BASE_URL:-https://pet-motion-lab-api.onrender.com}"

echo "📝 配置信息:"
echo "  API URL: $API_URL"
echo ""

# 清理之前的构建
echo "🧹 清理旧的构建文件..."
flutter clean

# 获取依赖
echo "📦 获取依赖..."
flutter pub get

# 构建 Web（使用 CanvasKit 渲染器以获得更好的性能）
echo "🔨 构建 Web 应用..."
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=API_BASE_URL="$API_URL"

echo ""
echo "✅ 构建完成！"
echo "📁 输出目录: build/web"
echo ""
echo "💡 提示："
echo "  - 可以使用 'python -m http.server -d build/web 8080' 本地测试"
echo "  - 部署到 Render 时会自动使用这个构建"

