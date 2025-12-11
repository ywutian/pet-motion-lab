# Render 部署指南（Railway 替代方案）

如果你的 Railway 账户处于受限计划，可以使用 Render 免费部署。

## 📋 前置要求

1. **Render 账户**：访问 [render.com](https://render.com) 注册账户（免费）
2. **GitHub 仓库**：确保代码已推送到 GitHub
3. **API 密钥**：准备好以下密钥
   - 可灵AI图片API密钥（KLING_ACCESS_KEY, KLING_SECRET_KEY）
   - 可灵AI视频API密钥（KLING_VIDEO_ACCESS_KEY, KLING_VIDEO_SECRET_KEY）
   - Google AI API密钥（可选，GOOGLE_API_KEY）

## 🚀 部署步骤

### 1. 连接 GitHub 仓库

1. 登录 Render 控制台
2. 点击 **"New +"** → **"Web Service"**
3. 选择 **"Build and deploy from a Git repository"**
4. 授权 Render 访问你的 GitHub 账户
5. 选择 `pet-motion-lab` 仓库

### 2. 配置部署设置

**基本设置：**
- **Name**: `pet-motion-lab-backend`（或你喜欢的名称）
- **Region**: 选择离你最近的区域（如 `Oregon (US West)`）
- **Branch**: `main`（或你的主分支）
- **Root Directory**: 留空（使用项目根目录）
- **Runtime**: `Docker`
- **Dockerfile Path**: `Dockerfile`（已自动检测）

**计划选择：**
- **Free**: 免费，但应用在 15 分钟无活动后会休眠（首次访问需要几秒唤醒）
- **Starter ($7/月)**: 无休眠限制，适合生产环境

### 3. 设置环境变量

在 **"Environment Variables"** 部分，添加以下环境变量：

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
PYTHONUNBUFFERED=1
PYTHONPATH=/app/backend
```

**设置方法：**
1. 在环境变量部分，点击 **"Add Environment Variable"**
2. 输入变量名和值
3. 点击 **"Save Changes"**

### 4. 高级设置（可选）

**Health Check Path**: `/health`

### 5. 部署

1. 点击 **"Create Web Service"**
2. Render 会自动开始构建和部署
3. 你可以在 **"Events"** 标签页查看部署日志
4. 等待构建完成（通常需要 3-5 分钟）

### 6. 获取部署 URL

1. 部署完成后，Render 会自动生成一个公共 URL
2. 格式：`https://你的服务名.onrender.com`
3. 你可以在 **"Settings"** → **"Custom Domain"** 中添加自定义域名

### 7. 验证部署

访问以下端点验证部署是否成功：

- **健康检查**: `https://你的域名/health`
- **API 文档**: `https://你的域名/docs`
- **根路径**: `https://你的域名/`
- **测试API密钥**: `https://你的域名/test-api-keys`

## 🔧 使用 render.yaml（可选）

如果你使用 `render.yaml` 配置文件：

1. 在 Render 创建服务时，选择 **"Apply render.yaml"**
2. Render 会自动读取 `render.yaml` 配置
3. 你仍然需要在 Render Dashboard 中设置环境变量（不要在 yaml 中写密钥）

## 📊 监控和日志

### 查看日志

1. 在 Render 服务页面，点击 **"Logs"** 标签页
2. 可以实时查看应用日志

### 监控指标

Render 提供以下监控：
- CPU 使用率
- 内存使用率
- 请求数
- 响应时间

## 🔄 更新部署

每次推送到 GitHub 主分支，Render 会自动重新部署。

你也可以手动触发部署：
1. 在 Render 服务页面
2. 点击 **"Manual Deploy"** → **"Deploy latest commit"**

## 🐛 故障排除

### 部署失败

1. **检查构建日志**：查看是否有依赖安装错误
2. **检查环境变量**：确保所有必需的环境变量都已设置
3. **检查 Dockerfile**：确保路径和命令正确

### 应用无法启动

1. **检查健康检查端点**：访问 `/health` 查看状态
2. **查看应用日志**：在 Render 控制台查看详细错误
3. **检查 API 密钥**：访问 `/test-api-keys` 验证密钥是否正确

### 应用休眠（免费计划）

- 免费计划的应用在 15 分钟无活动后会休眠
- 首次访问需要几秒唤醒时间
- 如果经常使用，考虑升级到 Starter 计划（$7/月）

## 💰 费用说明

Render 提供：
- **Free 计划**：免费，但有休眠限制
- **Starter 计划**：$7/月，无休眠限制，512MB RAM
- **Standard 计划**：$25/月，1GB RAM

对于小型项目，Free 计划通常足够使用。

## 📝 注意事项

1. **API 密钥安全**：不要在代码中硬编码密钥，始终使用环境变量
2. **文件存储**：容器重启后文件会丢失，考虑使用外部存储（如 AWS S3）
3. **CORS 配置**：生产环境应该限制 `allow_origins` 为具体的前端域名
4. **休眠问题**：免费计划会休眠，首次访问较慢

## 🔗 相关链接

- [Render 文档](https://render.com/docs)
- [FastAPI 文档](https://fastapi.tiangolo.com)
- [可灵AI API 文档](https://www.klingai.com)

## ✅ 部署检查清单

- [ ] Render 账户已创建
- [ ] GitHub 仓库已连接
- [ ] 环境变量已设置（KLING_ACCESS_KEY, KLING_SECRET_KEY 等）
- [ ] 部署成功完成
- [ ] 健康检查端点返回正常（/health）
- [ ] API 文档可访问（/docs）
- [ ] API 密钥测试通过（/test-api-keys）
- [ ] 前端已更新为使用新的后端 URL

---

如有问题，请查看 Render 的日志或联系技术支持。





