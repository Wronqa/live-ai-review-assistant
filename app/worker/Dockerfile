FROM python:3.11-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1 \
    TOKENIZERS_PARALLELISM=false


RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*


RUN pip install --no-cache-dir \
    --upgrade pip \
 && pip install --no-cache-dir \
    llama-cpp-python==0.2.77 \
    fastapi==0.111.0 \
    uvicorn==0.30.0


RUN mkdir -p /opt/models && \
    curl -L -o /opt/models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
    https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf && \
    ls -lh /opt/models


COPY main.py /app/

CMD ["python", "main.py"]
