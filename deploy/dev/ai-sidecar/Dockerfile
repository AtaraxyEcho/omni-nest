FROM python:3.11-slim

WORKDIR /app

# 图像推理运行库和模型下载证书。
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# PyTorch 使用 CPU 专用软件源，避免镜像携带无用的 CUDA 运行库。
RUN pip install --no-cache-dir \
    torch==2.12.0+cpu \
    torchvision==0.27.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV INSIGHTFACE_ROOT=/app/models/insightface \
    PLACES365_HOME=/app/models/places365 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TORCH_HOME=/app/models/torch

RUN mkdir -p \
    /app/models/insightface \
    /app/models/places365 \
    /app/models/torch

EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=10s --start-period=15m --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8090/ready', timeout=5)"]

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8090"]
