import os
import json
import logging
import sys
import threading
import re
from typing import Any, Dict, List

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("OMP_NUM_THREADS", "1")

import requests
import boto3
import torch
import datetime as _dt
import jwt  

from transformers import AutoModelForCausalLM, AutoTokenizer
from huggingface_hub import snapshot_download
from huggingface_hub.utils import HfHubHTTPError, RepositoryNotFoundError
from peft import PeftModel

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ecs-reviewer")

s3 = boto3.client("s3")
sm = boto3.client("secretsmanager")

def _is_sm_arn(v: str | None) -> bool:
    return bool(v and v.startswith("arn:aws:secretsmanager:"))

def _get_secret_value_by_arn(arn: str) -> str:
    resp = sm.get_secret_value(SecretId=arn)
    return resp.get("SecretString") or resp["SecretBinary"].decode()

def _env_or_secret(name: str) -> str | None:
    v = os.getenv(name)
    if not v:
        return None
    if _is_sm_arn(v):
        try:
            return _get_secret_value_by_arn(v)
        except Exception as e:
            log.error("Failed to resolve secret for %s: %s", name, e)
            raise
    return v

GITHUB_API_BASE = os.getenv("GITHUB_API_BASE", "https://api.github.com")
USER_AGENT = os.getenv("GITHUB_USER_AGENT", "ecs-reviewer")

GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN")

GITHUB_APP_ID = _env_or_secret("GITHUB_APP_ID")
GITHUB_APP_INSTALLATION_ID = _env_or_secret("GITHUB_APP_INSTALLATION_ID")
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

torch.set_num_threads(max(1, min(2, os.cpu_count() or 1)))

_model_lock = threading.Lock()
_model_ctx = {"tokenizer": None, "model": None}
_app_token_ctx = {"token": None, "exp_ts": 0}

def _utc_ts() -> int:
    return int(_dt.datetime.now(tz=_dt.timezone.utc).timestamp())

def _list_all_common_prefixes(bucket: str, delimiter: str = "/") -> List[str]:
    prefixes: List[str] = []
    params = {"Bucket": bucket, "Delimiter": delimiter}
    while True:
        resp = s3.list_objects_v2(**params)
        for p in resp.get("CommonPrefixes", []) or []:
            pr = p.get("Prefix", "")
            if pr:
                prefixes.append(pr.rstrip("/"))
        token = resp.get("NextContinuationToken")
        if not token:
            break
        params["ContinuationToken"] = token
    return prefixes

def _list_all_objects(bucket: str, prefix: str) -> List[Dict[str, Any]]:
    objs: List[Dict[str, Any]] = []
    params = {"Bucket": bucket, "Prefix": prefix}
    while True:
        resp = s3.list_objects_v2(**params)
        for obj in resp.get("Contents", []) or []:
            objs.append(obj)
        token = resp.get("NextContinuationToken")
        if not token:
            break
        params["ContinuationToken"] = token
    return objs

def _pick_latest_prefix(prefixes: List[str]) -> str:
    if not prefixes:
        raise RuntimeError("No adapter prefixes found in S3 bucket")
    return sorted(prefixes, reverse=True)[0]

def download_latest_adapter_from_s3() -> str:
    global LORA_ADAPTER_DIR
    os.makedirs(LORA_ADAPTER_DIR, exist_ok=True)

    prefixes = _list_all_common_prefixes(ADAPTER_BUCKET, delimiter="/")
    latest = _pick_latest_prefix(prefixes)
    log.info("Latest adapter prefix in S3: %s", latest)

    objs = _list_all_objects(ADAPTER_BUCKET, latest + "/")
    if not objs:
        raise RuntimeError(f"No objects found under prefix: {latest}")

    for obj in objs:
        key = obj["Key"]
        if key.endswith("/"):
            continue
        rel = os.path.relpath(key, latest)
        local_path = os.path.join(LORA_ADAPTER_DIR, rel)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        s3.download_file(ADAPTER_BUCKET, key, local_path)

    log.info("Adapter downloaded to %s", LORA_ADAPTER_DIR)
    return LORA_ADAPTER_DIR

def _load_github_app_private_key() -> str:
    if not GITHUB_APP_PRIVATE_KEY_SECRET_ARN:
        raise RuntimeError("Missing GITHUB_APP_PRIVATE_KEY_SECRET_ARN")

    pem = _get_secret_value_by_arn(GITHUB_APP_PRIVATE_KEY_SECRET_ARN)
    return pem

def _build_app_jwt(app_id: str, private_key_pem: str) -> str:
    now = _utc_ts()
    payload = {
        "iat": now - 60,     
        "exp": now + 9 * 60, 
        "iss": int(app_id),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def _fetch_installation_token(app_jwt: str, installation_id: str) -> dict:
    url = f"{GITHUB_API_BASE}/app/installations/{installation_id}/access_tokens"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {app_jwt}",
        "User-Agent": USER_AGENT,
    }
    resp = requests.post(url, headers=headers, timeout=HTTP_TIMEOUT_SEC)
    resp.raise_for_status()
    return resp.json()

def get_github_app_installation_token() -> str:
    if _app_token_ctx["token"] and _app_token_ctx["exp_ts"] - _utc_ts() > 60:
        return _app_token_ctx["token"]
    if not (GITHUB_APP_ID and GITHUB_APP_INSTALLATION_ID and GITHUB_APP_PRIVATE_KEY_SECRET_ARN):
        raise RuntimeError("GitHub App env vars not set")
    pem = _load_github_app_private_key()
    app_jwt = _build_app_jwt(GITHUB_APP_ID, pem)
    data = _fetch_installation_token(app_jwt, GITHUB_APP_INSTALLATION_ID)
    token = data["token"]
    exp_ts = int(_dt.datetime.fromisoformat(data["expires_at"].replace("Z", "+00:00")).timestamp())
    _app_token_ctx.update({"token": token, "exp_ts": exp_ts})
    return token

def get_token() -> str:
    if GITHUB_APP_ID and GITHUB_APP_INSTALLATION_ID and GITHUB_APP_PRIVATE_KEY_SECRET_ARN:
        t = get_github_app_installation_token()
        log.info("GitHub auth mode: app")
        return t

    if GITHUB_TOKEN_SECRET_ARN:
        if _is_sm_arn(GITHUB_TOKEN_SECRET_ARN):
            log.info("GitHub auth mode: pat (from secret)")
            return _get_secret_value_by_arn(GITHUB_TOKEN_SECRET_ARN)
        else:
            log.info("GitHub auth mode: pat (raw value)")
            return GITHUB_TOKEN_SECRET_ARN
    raise RuntimeError("Missing GitHub credentials: set GitHub App envs or GITHUB_TOKEN_SECRET_ARN")

def gh_request(method: str, url: str, token: str, **kw) -> requests.Response:
    headers = kw.pop("headers", {})
    headers.setdefault("Accept", "application/vnd.github+json")
    headers.setdefault("Authorization", f"Bearer {token}")
    headers.setdefault("User-Agent", USER_AGENT)
    resp = requests.request(method, url, headers=headers, timeout=HTTP_TIMEOUT_SEC, **kw)
    resp.raise_for_status()
    return resp

def make_marker(delivery_id: str | None, head_sha: str | None) -> str:
    parts = []
    if delivery_id:
        parts.append(f"delivery_id={delivery_id}")
    if head_sha:
        parts.append(f"head_sha={head_sha}")
    return f"<!-- {MARKER_PREFIX}:{' '.join(parts) if parts else 'no-id'} -->"

def existing_marker(owner: str, repo: str, pr: int, token: str, delivery_id: str, head_sha: str) -> bool:
    if not IDEMPOTENCY:
        return False
    marker = make_marker(delivery_id, head_sha).strip("<!-- ").strip(" -->")
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr}/reviews?per_page=100"
    while url:
        r = gh_request("GET", url, token)
        for rev in r.json():
            body = rev.get("body") or ""
            if MARKER_PREFIX in body and all(p in body for p in marker.split()):
                return True
        link = r.headers.get("Link", "") or ""
        nxt = None
        for p in [p.strip() for p in link.split(",") if p.strip()]:
            if 'rel="next"' in p:
                nxt = p[p.find("<") + 1 : p.find(">")]
        url = nxt
    return False

def pick_line(h: Dict[str, Any]) -> int:
    new_start = int(h.get("new_start") or 1)
    new_len = int(h.get("new_lines") or 1)
    return new_start if new_len <= 1 else new_start + (new_len // 2)

def load_hunks_from_s3(bucket: str, key: str) -> List[Dict[str, Any]]:
    obj = s3.get_object(Bucket=bucket, Key=key)
    data = json.loads(obj["Body"].read())
    hunks = data.get("hunks") or []
    if not isinstance(hunks, list):
        raise ValueError("Invalid artifact format: 'hunks' not a list")
    return hunks

def create_summary(owner, repo, pr, token, delivery_id, head_sha, count_comments, count_hunks):
    body = f"Automated review: {count_comments} suggestion(s) across {count_hunks} hunk(s).\n\n{make_marker(delivery_id, head_sha)}"
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr}/reviews"
    return gh_request("POST", url, token, json={"event": "COMMENT", "body": body}).json()

def post_inline(owner, repo, pr, token, head_sha, hunk, text):
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr}/comments"
    payload = {
        "body": text,
        "path": hunk["file_path"],
        "line": pick_line(hunk),
        "side": "RIGHT",
        "commit_id": head_sha,
    }
    return gh_request("POST", url, token, json=payload).json()

_DIFF_MARK_RE = re.compile(
    r"^(\+|-|@@|diff --git|index [0-9a-f]+\.\.[0-9a-f]+|\\ No newline)",
    re.I,
)

def _download_model(repo_id: str) -> str:
    return snapshot_download(repo_id=repo_id, local_dir=MODEL_DIR, local_dir_use_symlinks=False, token=None)

def get_model():
    if _model_ctx["model"] is not None:
        return _model_ctx["tokenizer"], _model_ctx["model"]
    with _model_lock:
        if _model_ctx["model"] is not None:
            return _model_ctx["tokenizer"], _model_ctx["model"]
        tried = [MODEL_ID, "bigcode/santacoder"]
        last_err = None
        for mid in tried:
            try:
                local_dir = _download_model(mid)
                tok = AutoTokenizer.from_pretrained(local_dir, use_fast=True)
                tok.padding_side = "right"
                tok.truncation_side = "left"
                if tok.pad_token is None and tok.eos_token is not None:
                    tok.pad_token = tok.eos_token

                model = AutoModelForCausalLM.from_pretrained(
                    local_dir,
                    torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
                    low_cpu_mem_usage=True,
                )
                model.eval()

                if LORA_ADAPTER_DIR:
                    try:
                        model = PeftModel.from_pretrained(model, LORA_ADAPTER_DIR)
                        model.eval()
                        log.info("LoRA adapter loaded from %s", LORA_ADAPTER_DIR)
                    except Exception as e:
                        log.warning("Could not load LoRA adapter: %s", e)

                _model_ctx["tokenizer"], _model_ctx["model"] = tok, model
                return tok, model
            except (RepositoryNotFoundError, HfHubHTTPError, Exception) as e:
                last_err = e
                log.warning("Model %s not available: %s", mid, e)
        raise RuntimeError(f"Could not load any model; last error: {last_err}")

def build_prompt(h: Dict[str, Any]) -> str:
    patch = (h.get("patch_hunk", "") or "")
    if TRUNCATE_HUNK_CHARS > 0 and len(patch) > TRUNCATE_HUNK_CHARS:
        patch = patch[:TRUNCATE_HUNK_CHARS] + "\n... [truncated]"
    return (
        "You are a senior code reviewer. Give exactly 1 short, actionable suggestion to improve the change.\n"
        "Code:\n"
        f"{patch}\n"
        "Suggestion:\n"
    )

def sanitize(text: str) -> str:
    t = (text or "").strip()
    t = re.sub(r"```.*?```", "", t, flags=re.S)
    lines = [ln for ln in t.splitlines() if not _DIFF_MARK_RE.match(ln.strip())]
    t = " ".join(ln.strip() for ln in lines if ln.strip())
    t = re.sub(r"^\s*(Suggestion|Review)\s*:?\s*", "", t, flags=re.I)
    t = t.split("\n", 1)[0]
    parts = re.split(r"(?<=[.!?])\s+", t)
    t = (parts[0] if parts else t).strip()
    if MAX_BODY_CHARS > 0:
        t = t[:MAX_BODY_CHARS].rstrip()
    return t or "Consider adding a unit test for this change."

def llm_suggest(h: Dict[str, Any]) -> str:
    tok, model = get_model()
    prompt = build_prompt(h)
    inputs = tok(prompt, return_tensors="pt").to(model.device)
    input_len = inputs["input_ids"].shape[1]
    with torch.no_grad():
        out = model.generate(
            **inputs,
            max_new_tokens=min(GEN_MAX_NEW_TOKENS, 64),
            do_sample=False,
            eos_token_id=tok.eos_token_id,
            pad_token_id=tok.eos_token_id,
        )
    text = tok.decode(out[0][input_len:], skip_special_tokens=True)
    return sanitize(text)

def heuristic_fallback(h: Dict[str, Any]) -> str:
    patch = h.get("patch_hunk", "") or ""
    if "print(" in patch or "console.log(" in patch:
        return "Replace prints with proper logging and disable debug logs in production."
    return "Consider adding a unit test and improving naming for clarity."

def suggest(h: Dict[str, Any]) -> str:
    if LLM_DISABLED:
        return heuristic_fallback(h)
    try:
        t = llm_suggest(h)
        if not t or len(t) < 5:
            return heuristic_fallback(h)
        return t
    except Exception as e:
        log.warning("LLM failed, using fallback: %s", e)
        return heuristic_fallback(h)

def handle_event(evt: Dict[str, Any]) -> None:
    owner = evt.get("owner")
    repo = evt.get("repo")
    pr = evt.get("pr_number")
    head_sha = evt.get("head_sha")
    delivery_id = evt.get("delivery_id")
    artifact = (evt.get("artifact") or {})
    bucket = artifact.get("s3_bucket")
    key = artifact.get("s3_key")
    if not (owner and repo and pr and head_sha and bucket and key):
        raise ValueError("Missing required fields")

    token = get_token()

    if IDEMPOTENCY and existing_marker(owner, repo, int(pr), token, delivery_id, head_sha):
        log.info("Duplicate marker found, skip")
        return

    hunks = load_hunks_from_s3(bucket, key)
    if MAX_HUNKS_LIMIT and len(hunks) > MAX_HUNKS_LIMIT:
        hunks = hunks[:MAX_HUNKS_LIMIT]

    comments = [{"h": h, "t": suggest(h)} for h in hunks]

    rev = create_summary(owner, repo, int(pr), token, delivery_id, head_sha, len(comments), len(hunks))

    posted = 0
    for c in comments:
        try:
            if not c["t"]:
                continue
            post_inline(owner, repo, int(pr), token, head_sha, c["h"], c["t"])
            posted += 1
        except Exception:
            log.exception("Inline failed for %s", c["h"].get("file_path"))

    log.info("Review id=%s; inline posted=%d", rev.get("id"), posted)

def main():
    raw = os.environ.get("PAYLOAD", "<brak>")
    print(raw)
    if not raw:
        print("Missing EVENT env with SQS message body", file=sys.stderr)
        sys.exit(2)
    try:
        evt = json.loads(raw)
    except Exception as e:
        print(f"Bad EVENT JSON: {e}", file=sys.stderr)
        sys.exit(3)
    try:
        download_latest_adapter_from_s3()
    except Exception as e:
        log.warning("Adapter download failed (continuing without): %s", e)
    try:
        handle_event(evt)
    except Exception as e:
        log.exception("Processing failed: %s", e)
        sys.exit(1)

if __name__ == "__main__":
    main()
