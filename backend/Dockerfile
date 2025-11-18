# 使用 Python 3.11 官方镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（rembg 需要）
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 复制 requirements.txt
COPY requirements.txt .

# 安装 Python 依赖（仅安装轻量级依赖）
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn[standard] \
    python-multipart \
    rembg \
    pyjwt \
    pillow \
    requests \
    pydantic \
    opencv-python-headless

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p output/uploads output/kling_tools temp

# 暴露端口
EXPOSE 8002

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8002/health')"

# 启动命令
CMD ["python", "main_kling_only.py"]

