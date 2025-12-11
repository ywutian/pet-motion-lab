# Railway 快速检查清单

## ✅ 配置已就绪

你的项目已经配置好了 Railway 部署：

- ✅ `railway.toml` - Railway 配置文件
- ✅ `Dockerfile` - Docker 构建文件
- ✅ `.dockerignore` - 优化构建速度
- ✅ 端口配置 - 支持 Railway 的 PORT 环境变量
- ✅ 健康检查 - `/health` 端点已配置

## 🔍 检查账户状态

### 步骤 1：检查是否受限

1. 登录 [railway.app](https://railway.app)
2. 查看是否有黄色横幅显示 "Limited Access"
3. 如果有，需要升级账户

### 步骤 2：升级账户（如果需要）

1. 点击右上角头像 → **"Settings"**
2. 进入 **"Billing"** 标签页
3. 点击 **"Upgrade"** 或 **"Add Payment Method"**
4. 选择 **Hobby 计划**（$5/月）
   - 包含 $5 免费额度
   - 实际可能不收费（如果使用量在额度内）
5. 添加支付方式（信用卡）
6. 确认升级

### 步骤 3：验证升级

- 受限提示应该消失
- 可以正常创建和部署服务

## 🚀 开始部署

一旦账户状态正常，按以下步骤部署：

### 1. 创建新项目

1. 在 Railway Dashboard，点击 **"New Project"**
2. 选择 **"Deploy from GitHub repo"**
3. 授权 GitHub 访问
4. 选择 `pet-motion-lab` 仓库

### 2. 跳过数据库（可选）

- Railway 可能提示添加数据库
- 直接点击 **"Skip"** 或关闭
- 应用可以正常运行（历史记录不会持久化）

### 3. 设置环境变量

在项目设置 → **"Variables"** 标签，添加：

```
KLING_ACCESS_KEY=你的密钥
KLING_SECRET_KEY=你的密钥
KLING_VIDEO_ACCESS_KEY=你的密钥
KLING_VIDEO_SECRET_KEY=你的密钥
KLING_OVERSEAS_BASE_URL=https://api.klingai.com
```

### 4. 等待部署

- Railway 会自动检测 `Dockerfile` 并开始构建
- 查看 **"Deployments"** 标签页的日志
- 通常需要 3-5 分钟

### 5. 获取 URL

- 部署完成后，Railway 会生成公共 URL
- 格式：`https://xxx.up.railway.app`
- 可以在 Settings → Domains 查看

### 6. 验证部署

访问以下端点验证：

- `https://你的域名/health` - 健康检查
- `https://你的域名/docs` - API 文档
- `https://你的域名/test-api-keys` - 测试 API 密钥

## 💡 常见问题

### Q: 为什么显示 "Limited Access"？

**A:** 账户处于受限计划，需要升级到 Hobby 计划（$5/月）

### Q: 升级后还是受限？

**A:** 
1. 检查支付方式是否有效
2. 等待几分钟让系统更新
3. 刷新页面
4. 如果还是不行，联系 Railway 支持

### Q: Hobby 计划真的需要付费吗？

**A:** 
- 需要添加支付方式
- 但包含 $5/月免费额度
- 如果使用量在额度内，可能不收费
- 超出部分按使用量计费

### Q: 可以跳过数据库吗？

**A:** 可以！数据库是可选的，应用可以正常运行，只是任务历史不会持久化。

## 📞 需要帮助？

如果遇到问题：

1. 查看 Railway 部署日志
2. 检查环境变量是否正确设置
3. 访问 `/health` 端点查看状态
4. 查看 Railway 文档：https://docs.railway.app

---

**你的配置已经准备好了，只需要：**
1. ✅ 确保账户是付费计划（Hobby $5/月）
2. ✅ 连接 GitHub 仓库
3. ✅ 设置环境变量
4. ✅ 等待部署完成

就可以开始使用了！

