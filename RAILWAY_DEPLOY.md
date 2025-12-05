# 🚀 Pet Motion Lab 部署指南

## 部署架构

| 组件 | 平台 | 特点 |
|------|------|------|
| **后端 API** | Railway | Docker 部署，自动扩展 |
| **前端 Web** | Vercel | 免费，全球 CDN，永不休眠 |

---

## 📋 准备工作

### 1. 注册 Railway 账号

访问 [railway.app](https://railway.app)，使用 GitHub 账号登录。

### 2. 确保代码已推送到 GitHub

```bash
git add .
git commit -m "Update Railway deployment config"
git push origin main
```

---

## ☁️ 部署后端 API

### 步骤 1: 创建新项目

1. 登录 Railway Dashboard
2. 点击 **"New Project"**
3. 选择 **"Deploy from GitHub repo"**
4. 选择你的仓库 `ywutian/pet-motion-lab`

### 步骤 2: 配置服务

Railway 会自动检测 `railway.toml` 和 `Dockerfile`，配置如下：

- **Build**: 使用 Dockerfile
- **Port**: 8002（自动检测）

### 步骤 3: 设置环境变量

在 Railway 项目设置中添加：

| 变量名 | 值 |
|--------|-----|
| `KLING_ACCESS_KEY` | 你的可灵 AI Access Key |
| `KLING_SECRET_KEY` | 你的可灵 AI Secret Key |

点击 **Variables** → **New Variable** 添加。

### 步骤 4: 生成域名

1. 点击 **Settings** → **Networking**
2. 点击 **"Generate Domain"**
3. 你会得到类似 `pet-motion-lab-api.up.railway.app` 的域名

### 步骤 5: 验证部署

访问：`https://你的域名.up.railway.app/health`

应该看到：
```json
{
  "status": "healthy",
  "api_version": "2.0.0",
  "mode": "kling_only"
}
```

---

## 🌐 部署前端 Web (Vercel)

项目已配置 `vercel.json`，Vercel 会自动识别。

### 步骤 1: 登录 Vercel

1. 访问 [vercel.com](https://vercel.com)
2. 使用 GitHub 账号登录

### 步骤 2: 导入项目

1. 点击 **"Add New..."** → **"Project"**
2. 选择 **"Import Git Repository"**
3. 找到并选择 `ywutian/pet-motion-lab`

### 步骤 3: 配置构建

Vercel 会自动读取 `vercel.json`，但需要确认：

- **Framework Preset**: `Other`
- **Root Directory**: `./`（默认）
- **Build Command**: 已在 vercel.json 中配置
- **Output Directory**: 已在 vercel.json 中配置

### 步骤 4: 设置环境变量（可选）

如果需要自定义后端地址，添加环境变量：
- `API_BASE_URL` = `https://你的railway域名.up.railway.app`

### 步骤 5: 部署

点击 **"Deploy"**，等待构建完成（约 3-5 分钟）。

### 步骤 6: 获取域名

部署成功后，Vercel 会提供：
- 默认域名: `pet-motion-lab.vercel.app`
- 或自定义域名

---

## 💰 Railway 定价

| 计划 | 价格 | 特点 |
|------|------|------|
| **Hobby** | $5/月 | 不休眠，500 小时/月 |
| **Pro** | $20/月 | 更多资源，团队功能 |

⚠️ **注意**: 免费试用版有限制，建议升级到 Hobby 计划以避免休眠。

---

## 🔧 常用操作

### 查看日志

在 Railway Dashboard 点击你的服务 → **Logs**

### 重新部署

```bash
git push origin main
```
Railway 会自动检测并重新部署。

### 更新环境变量

在 Dashboard → **Variables** 中修改。

### 回滚版本

在 **Deployments** 中选择之前的版本，点击 **Rollback**。

---

## 🆘 常见问题

### Q: 部署失败？

1. 检查 Railway 的 **Build Logs**
2. 确认 Dockerfile 正确
3. 确认环境变量已设置

### Q: API 调用失败？

1. 检查环境变量 `KLING_ACCESS_KEY` 和 `KLING_SECRET_KEY`
2. 查看后端日志
3. 确认前端 API 地址配置正确

### Q: 如何保持不休眠？

升级到 Hobby 计划（$5/月），Railway 会保持服务活跃。

---

## ✅ 部署完成后

- 🌐 前端网站: `https://pet-motion-lab.vercel.app`
- 🔌 后端 API: `https://pet-motion-lab-api.up.railway.app`
- 📚 API 文档: `https://pet-motion-lab-api.up.railway.app/docs`

---

## 🔄 更新部署

### 更新代码

```bash
git add .
git commit -m "Update"
git push origin main
```

Railway 和 Vercel 都会自动检测并重新部署。

### 更新后端 API 地址

如果 Railway 域名变了，需要：

1. 更新 `vercel.json` 中的 `API_BASE_URL`
2. 或在 Vercel 环境变量中设置 `API_BASE_URL`
3. 重新部署前端

