# 🐾 Pet Motion Lab

基于可灵AI的宠物动画生成实验室 - 让你的宠物照片动起来！

## ✨ 功能特性

- 🎨 **图生图**: 使用可灵AI将宠物照片转换为不同姿势
- 🎬 **图生视频**: 生成宠物动画视频
- 🔄 **首尾帧过渡**: 创建平滑的姿势过渡动画
- ✂️ **背景去除**: 自动去除图片背景
- 🎞️ **视频裁剪**: 裁剪和提取视频帧
- 📱 **多平台支持**: Android、iOS、Web、macOS、Windows

## 🚀 快速开始

### 本地运行

#### 1. 启动后端

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install fastapi uvicorn[standard] python-multipart rembg pyjwt pillow requests pydantic opencv-python-headless
python main_kling_only.py
```

后端将运行在 `http://localhost:8002`

#### 2. 启动前端

```bash
flutter pub get
flutter run
```

### 云端部署

想让别人也能使用你的应用？查看部署指南：

- 📖 [完整部署指南](DEPLOYMENT.md) - 详细的部署步骤
- ⚡ [快速部署指南](QUICK_DEPLOY.md) - 5分钟快速部署

## 🛠️ 技术栈

### 后端
- **FastAPI**: 高性能 Python Web 框架
- **可灵AI API**: 图像和视频生成
- **Rembg**: 背景去除
- **OpenCV**: 视频处理

### 前端
- **Flutter**: 跨平台 UI 框架
- **Provider**: 状态管理
- **Dio**: HTTP 客户端

## 📁 项目结构

```
pet_motion_lab/
├── backend/              # Python 后端
│   ├── api/             # API 路由
│   ├── services/        # 业务逻辑
│   ├── utils/           # 工具函数
│   └── main_kling_only.py  # 入口文件
├── lib/                 # Flutter 前端
│   ├── config/          # 配置文件
│   ├── models/          # 数据模型
│   ├── providers/       # 状态管理
│   ├── screens/         # 页面
│   ├── services/        # API 服务
│   └── widgets/         # UI 组件
└── docs/                # 文档
```

## 🔐 环境配置

### 后端环境变量

在 `backend/.env` 文件中配置：

```env
KLING_ACCESS_KEY=你的_access_key
KLING_SECRET_KEY=你的_secret_key
```

### 前端配置

API 地址会根据运行环境自动配置：
- **本地开发**: `http://localhost:8002`
- **Android 真机**: `http://10.0.0.120:8002` (需修改为你的电脑IP)
- **生产环境**: 通过 `--dart-define=API_BASE_URL=...` 指定

## 📚 API 文档

启动后端后，访问：
- Swagger UI: `http://localhost:8002/docs`
- ReDoc: `http://localhost:8002/redoc`

## 🎯 主要功能

### 1. 可灵AI工具
- **图生图**: 根据提示词生成新图片
- **图生视频**: 将静态图片转换为动画
- **首尾帧生成**: 创建平滑的过渡动画

### 2. 图像处理
- **背景去除**: 使用 Rembg 自动去除背景
- **图片裁剪**: 调整图片尺寸和比例

### 3. 视频处理
- **视频裁剪**: 精确裁剪视频片段
- **帧提取**: 提取视频的特定帧

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 🙏 致谢

- [可灵AI](https://klingai.com) - 提供强大的图像和视频生成能力
- [Flutter](https://flutter.dev) - 优秀的跨平台框架
- [FastAPI](https://fastapi.tiangolo.com) - 现代化的 Python Web 框架

---

Made with ❤️ by Pet Motion Lab Team

