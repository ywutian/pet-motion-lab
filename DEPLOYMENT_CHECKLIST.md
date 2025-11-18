# ✅ 部署前检查清单

在部署到 Render 之前，请确保完成以下步骤：

## 📋 本地测试

### 1. 后端测试
- [ ] 创建 `backend/.env` 文件并填入密钥
- [ ] 安装后端依赖：
  ```bash
  cd backend
  pip install fastapi uvicorn[standard] python-multipart rembg pyjwt pillow requests pydantic opencv-python-headless python-dotenv
  ```
- [ ] 测试环境变量：`python test_env.py`
- [ ] 启动后端：`python main_kling_only.py`
- [ ] 访问 `http://localhost:8002/health` 确认运行正常
- [ ] 访问 `http://localhost:8002/docs` 查看 API 文档

### 2. 前端测试
- [ ] 安装前端依赖：`flutter pub get`
- [ ] 运行前端：`flutter run -d chrome`
- [ ] 测试主要功能：
  - [ ] 上传图片
  - [ ] 背景去除
  - [ ] 图生图
  - [ ] 图生视频

### 3. 安全检查
- [ ] 确认 `.env` 文件已被 `.gitignore` 忽略
- [ ] 确认没有硬编码的密钥会被提交到 Git
- [ ] 运行 `git status` 确认 `.env` 不在待提交列表中

## 🚀 GitHub 准备

### 1. Git 配置
- [ ] 初始化 Git 仓库：`git init`（如果还没有）
- [ ] 添加所有文件：`git add .`
- [ ] 提交：`git commit -m "Ready for deployment"`
- [ ] 检查 `.gitignore` 是否正确配置

### 2. 创建 GitHub 仓库
- [ ] 访问 [GitHub](https://github.com) 创建新仓库
- [ ] 记下仓库地址
- [ ] 添加远程仓库：`git remote add origin <仓库地址>`
- [ ] 推送代码：`git push -u origin main`

## ☁️ Render 部署

### 1. 注册账号
- [ ] 访问 [Render.com](https://render.com)
- [ ] 使用 GitHub 账号登录

### 2. 部署后端 API
- [ ] 点击 "New +" → "Web Service"
- [ ] 连接 GitHub 仓库
- [ ] 配置服务：
  - Name: `pet-motion-lab-api`
  - Root Directory: `backend`
  - Build Command: `pip install fastapi uvicorn[standard] python-multipart rembg pyjwt pillow requests pydantic opencv-python-headless`
  - Start Command: `python main_kling_only.py`
  - Instance Type: `Free`
- [ ] 添加环境变量：
  - `KLING_ACCESS_KEY` = 你的密钥
  - `KLING_SECRET_KEY` = 你的密钥
- [ ] 点击 "Create Web Service"
- [ ] 等待部署完成（约 5-10 分钟）
- [ ] 记下 API 地址（如 `https://pet-motion-lab-api.onrender.com`）
- [ ] 测试 API：访问 `https://你的地址.onrender.com/health`

### 3. 部署前端 Web
- [ ] 点击 "New +" → "Static Site"
- [ ] 连接同一个 GitHub 仓库
- [ ] 配置服务：
  - Name: `pet-motion-lab-web`
  - Build Command: 
    ```
    flutter pub get && flutter build web --release --web-renderer canvaskit --dart-define=API_BASE_URL=https://你的后端地址.onrender.com
    ```
  - Publish Directory: `build/web`
- [ ] 点击 "Create Static Site"
- [ ] 等待部署完成（约 10-15 分钟）
- [ ] 记下网站地址（如 `https://pet-motion-lab-web.onrender.com`）

## ✅ 部署后测试

### 1. 后端测试
- [ ] 访问 `https://你的后端地址.onrender.com/health`
- [ ] 应该看到 `{"status": "healthy", ...}`
- [ ] 访问 `https://你的后端地址.onrender.com/docs`
- [ ] 应该看到 API 文档

### 2. 前端测试
- [ ] 访问 `https://你的前端地址.onrender.com`
- [ ] 应该看到应用界面
- [ ] 测试主要功能：
  - [ ] 上传图片
  - [ ] 背景去除
  - [ ] 图生图
  - [ ] 图生视频

### 3. 集成测试
- [ ] 在前端上传图片
- [ ] 调用后端 API
- [ ] 确认功能正常工作

## 📝 记录信息

部署完成后，记录以下信息：

```
后端 API 地址: https://_____________________.onrender.com
前端网站地址: https://_____________________.onrender.com
部署时间: ___________________
```

## 🎉 完成！

恭喜！你的 Pet Motion Lab 已经成功部署到云端了！

现在你可以：
- 分享前端网站地址给其他人使用
- 在 Render Dashboard 查看日志和监控
- 通过 Git 推送更新代码，Render 会自动重新部署

## 🆘 遇到问题？

如果遇到问题，请检查：
1. Render 的部署日志（Logs）
2. 环境变量是否正确设置
3. API 地址是否正确配置
4. 查看 [DEPLOYMENT.md](DEPLOYMENT.md) 了解详细步骤

