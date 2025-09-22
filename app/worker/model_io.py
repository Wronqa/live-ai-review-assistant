from __future__ import annotations

import os
import re
import threading
from typing import Any, Dict, Tuple

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from huggingface_hub import snapshot_download
from huggingface_hub.utils import HfHubHTTPError, RepositoryNotFoundError
from peft import PeftModel

from .logutil import setup_logger
from .config import (
    MODEL_DIR, MODEL_ID, GEN_MAX_NEW_TOKENS, TRUNCATE_HUNK_CHARS,
    LORA_ADAPTER_DIR, MAX_BODY_CHARS, LLM_DISABLED
)

log = setup_logger("model-io")

os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("OMP_NUM_THREADS", "1")
torch.set_num_threads(max(1, min(2, os.cpu_count() or 1)))

_model_lock = threading.Lock()
_model_ctx = {"tokenizer": None, "model": None}

_DIFF_MARK_RE = re.compile(
    r"^(\+|-|@@|diff --git|index [0-9a-f]+\.\.[0-9a-f]+|\\ No newline)",
    re.I,
)

def _download_model(repo_id: str) -> str:
    return snapshot_download(
        repo_id=repo_id,
        local_dir=MODEL_DIR,
        local_dir_use_symlinks=False,
        token=None
    )

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
