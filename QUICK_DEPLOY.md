# ⚡ 快速部署指南（5分钟）

## 🎯 目标
将 Pet Motion Lab 部署到 Render，让别人可以通过网页访问。

---

## 📝 准备工作

### 1. 保护你的密钥

```bash
cd backend
cp .env.example .env
# 编辑 .env 文件，填入你的可灵AI密钥
```

### 2. 推送到 GitHub

```bash
# 如果还没有 Git 仓库
git init
git add .
git commit -m "Ready for deployment"

# 在 GitHub 创建仓库后
git remote add origin https://github.com/你的用户名/pet-motion-lab.git
git push -u origin main
```

---

## ☁️ 部署步骤

### 步骤 1: 注册 Render
访问 [render.com](https://render.com)，用 GitHub 账号登录。

### 步骤 2: 部署后端
1. 点击 "New +" → "Web Service"
2. 选择你的 GitHub 仓库
3. 填写配置：
   ```
   Name: pet-motion-lab-api
   Root Directory: backend
   Build Command: pip install fastapi uvicorn[standard] python-multipart rembg pyjwt pillow requests pydantic opencv-python-headless
   Start Command: python main_kling_only.py
   ```
4. 添加环境变量：
   ```
   KLING_ACCESS_KEY = 你的密钥
   KLING_SECRET_KEY = 你的密钥
   ```
5. 点击 "Create Web Service"
6. 记下 API 地址（如 `https://pet-motion-lab-api.onrender.com`）

### 步骤 3: 部署前端
1. 点击 "New +" → "Static Site"
2. 选择同一个仓库
3. 填写配置：
   ```
   Name: pet-motion-lab-web
   Build Command: flutter pub get && flutter build web --release --web-renderer canvaskit --dart-define=API_BASE_URL=https://你的后端地址.onrender.com
   Publish Directory: build/web
   ```
4. 点击 "Create Static Site"

---

## ✅ 测试

访问你的网站地址（如 `https://pet-motion-lab-web.onrender.com`），应该能看到应用界面！

---

## 💡 提示

- 首次访问可能需要等待 30 秒（免费版会休眠）
- 每次推送代码到 GitHub，Render 会自动重新部署
- 详细文档请查看 `DEPLOYMENT.md`

---

## 🆘 遇到问题？

1. 查看 Render 的部署日志
2. 确认环境变量设置正确
3. 确认 API 地址配置正确

