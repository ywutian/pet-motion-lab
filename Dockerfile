# 使用 Python 3.11 官方镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（OpenCV 需要）
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 复制 requirements.txt
COPY backend/requirements.txt /app/backend/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir -r backend/requirements.txt

# 复制后端代码
COPY backend/ /app/backend/

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/backend

# 暴露端口
EXPOSE 8002

# 启动命令
CMD ["python", "backend/main_kling_only.py"]

