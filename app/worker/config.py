from __future__ import annotations
import os
import datetime as _dt

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

GITHUB_API_BASE = os.getenv("GITHUB_API_BASE", "https://api.github.com")
USER_AGENT = os.getenv("GITHUB_USER_AGENT", "ecs-reviewer")

GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN")
GITHUB_APP_ID_ARN = os.getenv("GITHUB_APP_ID_ARN")
GITHUB_APP_INSTALLATION_ID_ARN = os.getenv("GITHUB_APP_INSTALLATION_ID_ARN")
GITHUB_APP_PRIVATE_KEY_SECRET_ARN = os.getenv("GITHUB_APP_PRIVATE_KEY_SECRET_ARN")

MAX_BODY_CHARS = int(os.getenv("MAX_BODY_CHARS", "250"))
IDEMPOTENCY = os.getenv("IDEMPOTENCY", "true").lower() == "true"
MARKER_PREFIX = os.getenv("MARKER_PREFIX", "ecs")
HTTP_TIMEOUT_SEC = float(os.getenv("HTTP_TIMEOUT_SEC", "12"))

MODEL_ID = os.getenv("MODEL_ID", "Salesforce/codegen-350M-multi")
MODEL_DIR = os.getenv("MODEL_DIR", "/models")
GEN_MAX_NEW_TOKENS = int(os.getenv("GEN_MAX_NEW_TOKENS", "64"))
TRUNCATE_HUNK_CHARS = int(os.getenv("TRUNCATE_HUNK_CHARS", "600"))
LLM_DISABLED = os.getenv("LLM_DISABLED", "false").lower() == "true"
MAX_HUNKS_LIMIT = int(os.getenv("MAX_HUNKS", "0") or 0)

ADAPTER_BUCKET = os.getenv("ADAPTER_BUCKET", "codegen-350m-finetune-adapters")
LORA_ADAPTER_DIR = os.getenv("LORA_ADAPTER_DIR", "").strip() or "/models/adapters/latest"
os.environ["LORA_ADAPTER_DIR"] = LORA_ADAPTER_DIR

SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")           
SQS_RECEIPT_HANDLE = os.getenv("SQS_RECEIPT_HANDLE") 

def utc_ts() -> int:
    return int(_dt.datetime.now(tz=_dt.timezone.utc).timestamp())
