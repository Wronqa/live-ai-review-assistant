FROM python:3.11-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TRANSFORMERS_NO_ADVISORY_WARNINGS=1 \
    HF_HUB_ENABLE_HF_TRANSFER=0 \
    HF_HUB_DISABLE_SYMLINKS_WARNING=1 \
    HF_HUB_CACHE=/models/.cache/huggingface

RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs ca-certificates build-essential curl && \
    rm -rf /var/lib/apt/lists/* && git lfs install

RUN pip install --no-cache-dir --upgrade pip wheel

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app/worker

RUN mkdir -p /models/.cache/huggingface

ENV MODEL_DIR=/models \
    MODEL_ID=Salesforce/codegen-350M-multi \
    TOKENIZERS_PARALLELISM=false \
    OMP_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD python -c "import transformers,peft" || exit 1

CMD ["python", "-m", "worker.main"]
