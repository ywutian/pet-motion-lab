# Railway 部署指南

本指南将帮助你将 Pet Motion Lab 后端部署到 Railway 平台。

## ⚠️ 重要提示：Railway 账户限制

如果你的 Railway 账户显示 **"Limited Access - can only deploy databases"**，这意味着：

- **受限计划**：你的账户处于受限计划，只能部署数据库，**不能部署应用程序**
- **可能的原因**：
  1. 新账户默认是受限计划
  2. 之前的付费计划已过期
  3. 支付方式需要更新

- **解决方案**：
  1. **检查账户状态**：在 Railway Dashboard → Settings → Billing 查看账户状态
  2. **升级计划**：点击 "Upgrade your plan" 升级到 Hobby 计划（$5/月起）
  3. **恢复付费账户**：如果之前是付费账户，检查支付方式是否有效
  4. **使用替代平台**：如果不想付费，考虑使用其他免费平台（见下方"替代部署方案"）

### 如何恢复/升级 Railway 账户

1. **登录 Railway**：访问 [railway.app](https://railway.app)
2. **检查账户状态**：
   - 点击右上角头像 → **"Settings"**
   - 查看 **"Billing"** 标签页
   - 确认账户状态和支付方式
3. **升级到 Hobby 计划**：
   - 点击 **"Upgrade"** 或 **"Add Payment Method"**
   - 选择 **Hobby 计划**（$5/月，包含 $5 免费额度）
   - 添加支付方式（信用卡）
   - 确认升级
4. **验证升级**：
   - 升级后，受限提示应该消失
   - 可以正常部署应用程序

## 📋 前置要求

1. **Railway 账户**：访问 [railway.app](https://railway.app) 注册账户（需要付费计划才能部署应用）
2. **GitHub 仓库**：确保代码已推送到 GitHub
3. **API 密钥**：准备好以下密钥
   - 可灵AI图片API密钥（KLING_ACCESS_KEY, KLING_SECRET_KEY）
   - 可灵AI视频API密钥（KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY）
   - Google AI API密钥（可选，GOOGLE_API_KEY）

## 🚀 部署步骤

### 1. 连接 GitHub 仓库

1. 登录 Railway 控制台
2. 点击 **"New Project"**
3. 选择 **"Deploy from GitHub repo"**
4. 授权 Railway 访问你的 GitHub 账户
5. 选择 `pet-motion-lab` 仓库

### 2. 配置部署设置

Railway 会自动检测到 `railway.toml` 和 `Dockerfile`，使用 Docker 方式部署。

**重要配置：**
- **Root Directory**: 留空（使用项目根目录）
- **Dockerfile Path**: `Dockerfile`（已自动检测）
- **Health Check Path**: `/health`（已在 railway.toml 中配置）

### 2.1. 关于数据库（可选）

Railway 可能会提示你添加数据库。**数据库是可选的**，你可以：

**选项 A：跳过数据库（推荐用于快速测试）**
- 直接点击 **"Skip"** 或关闭数据库选择界面
- 应用可以正常运行，但任务历史记录在容器重启后会丢失
- 适合测试环境或不需要持久化历史的场景

**选项 B：添加 PostgreSQL（推荐用于生产环境）**
- 选择 **"Add PostgreSQL"**
- Railway 会自动创建 PostgreSQL 数据库并设置 `DATABASE_URL` 环境变量
- ⚠️ **注意**：当前代码使用 SQLite，需要修改代码以支持 PostgreSQL
- 如果需要持久化任务历史，建议后续修改代码支持 PostgreSQL

### 3. 设置环境变量

在 Railway 项目设置中，添加以下环境变量：

#### 必需的环境变量

```
KLING_ACCESS_KEY=你的可灵AI图片AccessKey
KLING_SECRET_KEY=你的可灵AI图片SecretKey
KLING_VIDEO_ACCESS_KEY=你的可灵AI视频AccessKey
KLING_VIDEO_SECRET_KEY=你的可灵AI视频SecretKey
KLING_OVERSEAS_BASE_URL=https://api.klingai.com
```

#### 可选的环境变量

```
GOOGLE_API_KEY=你的Google AI API密钥（用于图片内容审核）
ENABLE_AI_IMAGE_CHECK=true
PORT=8002（Railway会自动设置，无需手动配置）
```

**设置方法：**
1. 在 Railway 项目页面，点击 **"Variables"** 标签
2. 点击 **"New Variable"**
3. 输入变量名和值
4. 点击 **"Add"**

### 4. 部署

1. Railway 会自动开始构建和部署
2. 你可以在 **"Deployments"** 标签页查看部署日志
3. 等待构建完成（通常需要 3-5 分钟）

### 5. 获取部署 URL

1. 部署完成后，Railway 会自动生成一个公共 URL
2. 在项目设置中，点击 **"Settings"** → **"Domains"**
3. 你可以：
   - 使用 Railway 提供的默认域名（如 `xxx.up.railway.app`）
   - 或者添加自定义域名

### 6. 验证部署

访问以下端点验证部署是否成功：

- **健康检查**: `https://你的域名/health`
- **API 文档**: `https://你的域名/docs`
- **根路径**: `https://你的域名/`
- **测试API密钥**: `https://你的域名/test-api-keys`

## 🔧 配置说明

### railway.toml

```toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "Dockerfile"

[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 100
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
```

### Dockerfile

- 使用 Python 3.11 基础镜像
- 安装系统依赖（OpenCV 需要）
- 安装 Python 依赖
- 暴露端口 8002（Railway 会自动映射）
- 启动 FastAPI 服务器

### 端口配置

- Railway 会自动设置 `PORT` 环境变量
- 应用代码会自动从环境变量读取端口
- 如果未设置，默认使用 8002

## 📊 监控和日志

### 查看日志

1. 在 Railway 项目页面，点击 **"Deployments"**
2. 选择最新的部署
3. 查看 **"Logs"** 标签页

### 监控指标

Railway 提供以下监控：
- CPU 使用率
- 内存使用率
- 网络流量
- 请求数

## 🔄 更新部署

每次推送到 GitHub 主分支，Railway 会自动重新部署。

你也可以手动触发部署：
1. 在 Railway 项目页面
2. 点击 **"Deployments"**
3. 点击 **"Redeploy"**

## 🐛 故障排除

### 部署失败

1. **检查构建日志**：查看是否有依赖安装错误
2. **检查环境变量**：确保所有必需的环境变量都已设置
3. **检查 Dockerfile**：确保路径和命令正确

### 应用无法启动

1. **检查健康检查端点**：访问 `/health` 查看状态
2. **查看应用日志**：在 Railway 控制台查看详细错误
3. **检查 API 密钥**：访问 `/test-api-keys` 验证密钥是否正确

### 常见错误

#### 端口错误
- Railway 会自动设置 `PORT` 环境变量
- 确保应用代码使用 `os.environ.get("PORT", 8002)`

#### 依赖安装失败
- 检查 `requirements.txt` 是否包含所有依赖
- 某些依赖可能需要系统库（已在 Dockerfile 中安装）

#### 环境变量未生效
- 确保在 Railway 的 **"Variables"** 中正确设置
- 重新部署以应用新的环境变量

## 💰 费用说明

Railway 提供：
- **受限计划**：只能部署数据库，**不能部署应用程序**（免费）
- **付费计划**：$5/月起，可以部署应用程序

⚠️ **注意**：如果你看到 "Limited Access" 提示，需要升级到付费计划才能部署应用。

## 🔄 替代部署方案

如果你的 Railway 账户处于受限计划，可以考虑以下替代平台：

### 1. Render（推荐，免费）

**优点**：
- 免费套餐可用（有休眠限制）
- 支持 Docker 部署
- 自动 HTTPS
- 简单易用

**部署步骤**：
1. 访问 [render.com](https://render.com)
2. 连接 GitHub 仓库
3. 选择 "New Web Service"
4. 使用 Dockerfile 部署
5. 设置环境变量

### 2. Fly.io（推荐，免费额度）

**优点**：
- 免费套餐：3 个共享 CPU、256MB RAM
- 全球边缘部署
- 支持 Docker

**部署步骤**：
1. 访问 [fly.io](https://fly.io)
2. 安装 flyctl CLI
3. 运行 `fly launch` 初始化
4. 运行 `fly deploy` 部署

### 3. Heroku（付费，但简单）

**优点**：
- 部署简单
- 生态成熟
- 需要付费（$5/月起）

### 4. 其他选项

- **Vercel**：主要支持 Node.js，但可以通过 Serverless Functions 运行 Python
- **DigitalOcean App Platform**：$5/月起
- **AWS/GCP/Azure**：需要更多配置，但功能强大

### 快速迁移到 Render

如果你选择 Render，我可以帮你创建 `render.yaml` 配置文件，让部署更简单。

## 📝 注意事项

1. **API 密钥安全**：不要在代码中硬编码密钥，始终使用环境变量
2. **数据库**：如果需要持久化存储，考虑使用 Railway 的 PostgreSQL 服务
3. **文件存储**：容器重启后文件会丢失，考虑使用外部存储（如 AWS S3）
4. **CORS 配置**：生产环境应该限制 `allow_origins` 为具体的前端域名

## 🔗 相关链接

- [Railway 文档](https://docs.railway.app)
- [FastAPI 文档](https://fastapi.tiangolo.com)
- [可灵AI API 文档](https://www.klingai.com)

## ✅ 部署检查清单

- [ ] Railway 账户已创建
- [ ] GitHub 仓库已连接
- [ ] 环境变量已设置（KLING_ACCESS_KEY, KLING_SECRET_KEY 等）
- [ ] 部署成功完成
- [ ] 健康检查端点返回正常（/health）
- [ ] API 文档可访问（/docs）
- [ ] API 密钥测试通过（/test-api-keys）
- [ ] 前端已更新为使用新的后端 URL

---

如有问题，请查看 Railway 的日志或联系技术支持。

