# Scripts 目录

这个目录包含各种独立的脚本工具。

## 📁 目录结构

### `video/` - 视频处理脚本
- `cut_video_frames.py` - 根据起始帧和终止帧剪切视频
- `trim_video.py` - 保留视频的前N帧
- `reverse_video.py` - 视频倒放
- `convert_mp4_to_gif.py` - MP4转GIF（支持批量转换）

### `image/` - 图片处理脚本
- `extract_last_frame.py` - 提取视频最后一帧

### `setup/` - 设置和下载脚本
- `download_models.py` - 下载 Flux 模型
- `download_pose_library.py` - 下载姿态库
- `download_best_models.sh` - 下载最佳模型（Shell脚本）
- `verify_setup.py` - 验证环境设置

### 根目录脚本
- `generate_base_pet.py` - 生成基础宠物图片
- `batch_generate_base_pets.py` - 批量生成基础宠物图片

## 🚀 使用方法

所有脚本都可以直接运行：

```bash
# 视频处理示例
python scripts/video/cut_video_frames.py

# 图片处理示例
python scripts/image/extract_last_frame.py

# 设置脚本示例
python scripts/setup/download_models.py
```

## 📝 注意事项

- 这些脚本主要用于开发和测试
- 生产环境请使用 API 接口（`backend/api/`）
- 脚本中的路径可能需要根据实际情况调整

