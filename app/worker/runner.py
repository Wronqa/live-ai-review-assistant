from __future__ import annotations
from typing import Any, Dict, List
import sys
import os
import json

from .logutil import setup_logger
from .aws_utils import download_latest_adapter_from_s3, load_hunks_from_s3, requeue_message_on_failure
from .github_api import get_token
from .review_logic import (
    existing_marker, create_summary, post_inline, limit_hunks, prepare_comments
)

log = setup_logger("runner")

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

    if existing_marker(owner, repo, int(pr), token, delivery_id, head_sha):
        log.info("Duplicate marker found, skip")
        return

    hunks = load_hunks_from_s3(bucket, key)
    hunks = limit_hunks(hunks)
    comments = prepare_comments(hunks)

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

def entrypoint() -> int:
    raw = os.environ.get("PAYLOAD", "<missing>")
    print(raw)
    if not raw:
        print("Missing EVENT env with SQS message body", file=sys.stderr)
        return 2
    try:
        evt = json.loads(raw)
    except Exception as e:
        print(f"Bad EVENT JSON: {e}", file=sys.stderr)
        return 3

    try:
        download_latest_adapter_from_s3()
    except Exception as e:
        log.warning("Adapter download failed (continuing without): %s", e)

    try:
        handle_event(evt)
        return 0
    except Exception as e:
        log.exception("Processing failed: %s", e)
        requeue_message_on_failure()
        return 1
