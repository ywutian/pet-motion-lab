# 使用 Python 3.11 官方镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（OpenCV 和 python-magic 需要）
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# 复制 requirements.txt
COPY backend/requirements.txt /app/backend/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir -r backend/requirements.txt

# 复制后端代码
COPY backend/ /app/backend/

# 创建必要的目录并设置权限
RUN mkdir -p /app/backend/output /tmp/pet_motion_lab/uploads && \
    chmod -R 777 /app/backend/output /tmp/pet_motion_lab

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app/backend

# 暴露端口（Railway 会自动设置 PORT 环境变量）
EXPOSE 8002

# 启动命令
# Railway 会自动设置 PORT 环境变量，应用代码会从环境变量读取
CMD ["python", "backend/main_kling_only.py"]

