import os
import json
import hmac
import base64
import hashlib
from typing import Any, Dict, Optional, Tuple

import boto3
from botocore.exceptions import ClientError

_sm = boto3.client("secretsmanager")
_sqs = boto3.client("sqs")

try:
    WEBHOOK_SECRET_ID = os.environ["WEBHOOK_SECRET_ID"]
    PR_EVENTS_SQS_URL = os.environ["PR_EVENTS_SQS_URL"]
    ALLOWED_PR_ACTIONS = set(a.strip() for a in os.environ.get(
        "ALLOWED_PR_ACTIONS",
        "opened,reopened,synchronize,ready_for_review,edited"
    ).split(","))   
except KeyError as exc:
    raise RuntimeError(f"Missing required environment variable: {exc.args[0]}")

_secrets_cache: Dict[str, str] = {}

def _resp(status: int, payload: Dict[str, Any]) -> Dict[str, Any]:
    """Consistent API Gateway response."""
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(payload),
    }


def _get_secret(secret_id: str) -> str:
    """Fetch and cache the secret string by id."""
    if secret_id in _secrets_cache:
        return _secrets_cache[secret_id]

    try:
        resp = _sm.get_secret_value(SecretId=secret_id)
    except ClientError as e:
        print(f"[secrets] error: {e.response.get('Error', {}).get('Code')}")
        raise

    val = resp.get("SecretString") or ""
    _secrets_cache[secret_id] = val
    return val


def _verify_sig(
    secret: str, body: bytes, sig256: Optional[str], sig1: Optional[str]
) -> bool:
    """
    Verify GitHub webhook signature. Prefer sha256, fallback to legacy sha1 if provided.
    """
    if sig256:
        expected = "sha256=" + hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
        if hmac.compare_digest(expected, sig256):
            return True

    if sig1:
        expected = "sha1=" + hmac.new(secret.encode("utf-8"), body, hashlib.sha1).hexdigest()
        if hmac.compare_digest(expected, sig1):
            return True

    return False


def _get_raw_body(event: Dict[str, Any]) -> bytes:
    """Return the raw request body as bytes, handling base64 encoding if set."""
    body = event.get("body") or ""
    if event.get("isBase64Encoded"):
        return base64.b64decode(body)
    return body.encode("utf-8")


def _extract_headers(event: Dict[str, Any]) -> Dict[str, str]:
    headers = (event.get("headers") or {})
    return {str(k).lower(): str(v) for k, v in headers.items()}


def _is_fifo_queue(url: str) -> bool:
    return url.rstrip().endswith(".fifo")


def _prepare_message(p: Dict[str, Any], delivery_id: Optional[str]) -> Tuple[str, Dict[str, Any], Dict[str, Any]]:
    """
    Build SQS send_message kwargs: MessageBody + optional FIFO fields.
    Returns (message_body_str, message_attributes, extra_kwargs)
    """
    action = p.get("action")
    repo = p.get("repository", {}) or {}
    owner = (repo.get("owner") or {}).get("login")
    name = repo.get("name")
    pr = p.get("pull_request", {}) or {}

    before = p.get("before")
    after = p.get("after")

    msg = {
        "delivery_id": delivery_id,
        "event": "pull_request",
        "action": action,
        "owner": owner,
        "repo": name,
        "pr_number": pr.get("number"),
        "incremental": bool(before and after),
        "before": before,
        "after": after,
    }

    body_str = json.dumps(msg, separators=(",", ":"), ensure_ascii=False)
    attrs: Dict[str, Any] = {}

    extra: Dict[str, Any] = {}
    if _is_fifo_queue(PR_EVENTS_SQS_URL):
        dedup = delivery_id or body_str  
        extra["MessageGroupId"] = f"pr-events:{owner}/{name}"
        extra["MessageDeduplicationId"] = dedup

    return body_str, attrs, extra

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    headers = _extract_headers(event)
    gh_event = headers.get("x-github-event")
    delivery = headers.get("x-github-delivery")

    if gh_event == "ping":
        return _resp(200, {"ok": True, "pong": True})

    if gh_event != "pull_request":
        return _resp(200, {"ok": True, "ignored_event": gh_event})

    raw_body = _get_raw_body(event)

    sig256 = headers.get("x-hub-signature-256")
    sig1 = headers.get("x-hub-signature")

    try:
        secret = _get_secret(WEBHOOK_SECRET_ID)
    except ClientError:
        return _resp(500, {"ok": False, "error": "secrets_unavailable"})

    if not _verify_sig(secret, raw_body, sig256, sig1):
        return _resp(401, {"ok": False, "error": "invalid_signature"})

    try:
        p = json.loads(raw_body.decode("utf-8"))
    except Exception:
        return _resp(400, {"ok": False, "error": "invalid_json"})
    


    action = p.get("action")
    pr = p.get("pull_request") or {}
    state  = pr.get("state", "")    

    if action not in ALLOWED_PR_ACTIONS:
        return _resp(204, {"ignored": True, "reason": f"action_not_allowed:{action}"})
    if state != "open":
        return _resp(204, {"ignored": True, "reason": f"state:{state}"})
    if pr.get("draft", False):
        return _resp(204, {"ignored": True, "reason": "draft_pr"})


    repo = p.get("repository") or {}
    owner = (repo.get("owner") or {}).get("login")
    name = repo.get("name")
    prnum = pr.get("number")

    missing = [k for k, v in [("action", action), ("owner", owner), ("repo", name), ("pr_number", prnum)] if not v]

    if missing:
        return _resp(400, {"ok": False, "error": "missing_fields", "fields": missing})

    body_str, msg_attrs, extra_kwargs = _prepare_message(p, delivery_id=delivery)
    try:
        _sqs.send_message(
            QueueUrl=PR_EVENTS_SQS_URL,
            MessageBody=body_str,
            MessageAttributes=msg_attrs,
            **extra_kwargs,
        )
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code")
        print(f"[sqs] send_message error: {code}")
        return _resp(502, {"ok": False, "error": f"sqs:{code}"})

    return _resp(202, {"ok": True, "queued": True})