# 🚀 Pet Motion Lab 部署指南

本指南将帮助你将 Pet Motion Lab 部署到云端，让其他人可以通过网页访问。

## 📋 部署方案

我们使用 **Render** 免费部署方案：
- **后端 API**: Python FastAPI 服务
- **前端 Web**: Flutter Web 静态网站

### 为什么选择 Render？
- ✅ 完全免费（有免费套餐）
- ✅ 支持 Python 和静态网站
- ✅ 自动从 GitHub 部署
- ✅ 提供免费 HTTPS
- ⚠️ 免费版会在 15 分钟无活动后休眠（首次访问需要等待 30 秒唤醒）

---

## 🔐 第一步：准备密钥

### 1. 创建本地环境变量文件

在 `backend` 目录下创建 `.env` 文件：

```bash
cd backend
cp .env.example .env
```

编辑 `.env` 文件，填入你的可灵AI密钥：

```env
KLING_ACCESS_KEY=你的_access_key
KLING_SECRET_KEY=你的_secret_key
```

⚠️ **重要**: `.env` 文件已被添加到 `.gitignore`，不会被提交到 Git，保护你的密钥安全。

---

## 📦 第二步：推送代码到 GitHub

### 1. 初始化 Git 仓库（如果还没有）

```bash
git init
git add .
git commit -m "Initial commit: Pet Motion Lab"
```

### 2. 创建 GitHub 仓库

1. 访问 [GitHub](https://github.com)
2. 点击右上角 "+" → "New repository"
3. 填写仓库名称（如 `pet-motion-lab`）
4. 选择 "Public" 或 "Private"
5. 点击 "Create repository"

### 3. 推送代码

```bash
git remote add origin https://github.com/你的用户名/pet-motion-lab.git
git branch -M main
git push -u origin main
```

---

## ☁️ 第三步：部署到 Render

### 1. 注册 Render 账号

访问 [Render.com](https://render.com) 并注册账号（可以用 GitHub 账号登录）。

### 2. 部署后端 API

1. 在 Render Dashboard 点击 "New +" → "Web Service"
2. 连接你的 GitHub 仓库
3. 配置如下：
   - **Name**: `pet-motion-lab-api`
   - **Region**: 选择离你最近的区域（如 Oregon）
   - **Branch**: `main`
   - **Root Directory**: `backend`
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `python main_kling_only.py`
   - **Instance Type**: `Free`

4. 添加环境变量（Environment Variables）：
   - 点击 "Advanced" → "Add Environment Variable"
   - 添加以下变量：
     ```
     KLING_ACCESS_KEY = 你的_access_key
     KLING_SECRET_KEY = 你的_secret_key
     ```

5. 点击 "Create Web Service"

6. 等待部署完成（约 5-10 分钟），记下你的 API 地址：
   ```
   https://pet-motion-lab-api.onrender.com
   ```

### 3. 部署前端 Web

1. 在 Render Dashboard 点击 "New +" → "Static Site"
2. 连接同一个 GitHub 仓库
3. 配置如下：
   - **Name**: `pet-motion-lab-web`
   - **Branch**: `main`
   - **Build Command**: 
     ```bash
     flutter pub get && flutter build web --release --web-renderer canvaskit --dart-define=API_BASE_URL=https://pet-motion-lab-api.onrender.com
     ```
   - **Publish Directory**: `build/web`

4. 点击 "Create Static Site"

5. 等待部署完成，记下你的网站地址：
   ```
   https://pet-motion-lab-web.onrender.com
   ```

---

## ✅ 第四步：测试部署

### 1. 测试后端 API

访问：`https://pet-motion-lab-api.onrender.com/health`

应该看到：
```json
{
  "status": "healthy",
  "api_version": "2.0.0",
  "mode": "kling_only"
}
```

### 2. 测试前端网站

访问：`https://pet-motion-lab-web.onrender.com`

应该能看到你的 Pet Motion Lab 应用界面。

---

## 🔧 本地开发

### 后端开发

```bash
cd backend

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install fastapi uvicorn[standard] python-multipart rembg pyjwt pillow requests pydantic opencv-python-headless python-dotenv

# 测试环境变量配置
python test_env.py

# 启动服务器
python main_kling_only.py
```

访问：`http://localhost:8002`

### 前端开发

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run -d chrome
```

---

## 📝 注意事项

### Render 免费版限制

- ⏰ **休眠机制**: 15 分钟无活动后会休眠，下次访问需要 30 秒唤醒
- 💾 **存储**: 生成的文件会在服务重启后丢失（建议使用云存储）
- 🚀 **性能**: 免费版性能有限，适合演示和测试

### 安全建议

- ✅ 密钥已改为环境变量，不会泄露
- ✅ `.env` 文件已被 `.gitignore` 忽略
- ⚠️ 生产环境建议限制 CORS 允许的域名

---

## 🆘 常见问题

### Q: 部署失败怎么办？

查看 Render 的部署日志（Logs），通常会显示错误原因。

### Q: API 调用失败？

1. 检查环境变量是否正确设置
2. 检查 API 地址是否正确
3. 查看后端日志

### Q: 如何更新部署？

只需推送代码到 GitHub，Render 会自动重新部署：

```bash
git add .
git commit -m "Update"
git push
```

---

## 🎉 完成！

现在你的 Pet Motion Lab 已经部署到云端了！

- 🌐 前端网站: `https://pet-motion-lab-web.onrender.com`
- 🔌 后端 API: `https://pet-motion-lab-api.onrender.com`
- 📚 API 文档: `https://pet-motion-lab-api.onrender.com/docs`

