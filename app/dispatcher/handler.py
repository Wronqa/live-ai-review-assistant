import os
import re
import json
import time
import logging
from typing import Dict, Any, Iterable, List

import boto3
import requests

GITHUB_API_BASE   = os.environ.get("GITHUB_API_BASE", "https://api.github.com")
USER_AGENT        = os.environ.get("GITHUB_USER_AGENT", "codesense-dispatcher")

TARGET_QUEUE_URL  = os.environ["TARGET_QUEUE_URL"]         
ARTIFACTS_BUCKET  = os.environ["ARTIFACTS_BUCKET"]          
IDEMPOTENCY_TABLE = os.environ["IDEMPOTENCY_TABLE"]       


GITHUB_TOKEN      = os.environ.get("GITHUB_TOKEN")
GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN")

IGNORE_PATTERNS   = os.environ.get("IGNORE_PATHS", "package-lock.json,^.*/dist/.*,^.*/build/.*").split(",")
MAX_HUNKS         = int(os.environ.get("MAX_HUNKS", "6"))
HTTP_TIMEOUT      = float(os.environ.get("HTTP_TIMEOUT_SEC", "12"))


logger = logging.getLogger(__name__)
if not logging.getLogger().handlers:
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"),
                        format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

sqs = boto3.client("sqs")
s3  = boto3.client("s3")
sm  = boto3.client("secretsmanager")
ddb = boto3.resource("dynamodb").Table(IDEMPOTENCY_TABLE)

def get_token() -> str:
    if GITHUB_TOKEN:
        return GITHUB_TOKEN
    if not GITHUB_TOKEN_SECRET_ARN:
        raise RuntimeError("Missing GITHUB_TOKEN or GITHUB_TOKEN_SECRET_ARN")
    r = sm.get_secret_value(SecretId=GITHUB_TOKEN_SECRET_ARN)
    return r.get("SecretString") or r["SecretBinary"].decode()

def gh_request(method: str, url: str, token: str, **kw) -> requests.Response:
    headers = kw.pop("headers", {})
    headers.setdefault("Accept", "application/vnd.github+json")
    headers.setdefault("Authorization", f"Bearer {token}")
    headers.setdefault("User-Agent", USER_AGENT)
    resp = requests.request(method, url, headers=headers, timeout=HTTP_TIMEOUT, **kw)
    resp.raise_for_status()
    return resp

_HUNK_HDR_RE = re.compile(r"@@\s*-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@")

def parse_unified_hunks(patch: str, file_path: str) -> List[Dict[str, Any]]:
    """Extract unified diff hunks from a file patch."""
    if not patch:
        return []
    out: List[Dict[str, Any]] = []
    lines = patch.splitlines()
    i = 0
    while i < len(lines):
        m = _HUNK_HDR_RE.match(lines[i])
        if not m:
            i += 1
            continue
        old_start = int(m.group(1)); old_len = int(m.group(2) or "0")
        new_start = int(m.group(3)); new_len = int(m.group(4) or "0")
        buf = [lines[i]]; i += 1
        while i < len(lines) and not _HUNK_HDR_RE.match(lines[i]):
            buf.append(lines[i]); i += 1
        out.append({
            "file_path": file_path,
            "patch_hunk": "\n".join(buf),
            "new_start": new_start, "new_lines": new_len,
            "old_start": old_start, "old_lines": old_len
        })
    return out

def should_ignore_path(path: str) -> bool:
    path = path or ""
    for pat in IGNORE_PATTERNS:
        pat = pat.strip()
        if not pat:
            continue
        try:
            if pat.startswith("^"):
                if re.match(pat, path):
                    return True
            else:
                if pat in path:
                    return True
        except re.error:
            if pat in path:
                return True
    return False

def parse_messages(event: Dict[str, Any]):
    if "Records" in event:
        for rec in event["Records"]:
            body = rec.get("body") or "{}"
            try:
                yield json.loads(body)
            except Exception:
                logger.warning("Bad SQS body: %s", body)
    else:
        yield event

def ddb_put_once(delivery_id: str, head_sha: str) -> bool:
    """Idempotency using (delivery_id + head_sha)."""
    pk = f"{delivery_id}:{head_sha or 'nohead'}"
    try:
        ddb.put_item(
            Item={"pk": pk, "ttl": int(time.time()) + 7 * 24 * 3600},
            ConditionExpression="attribute_not_exists(pk)"
        )
        return True
    except Exception:
        return False

def enrich(owner: str, repo: str, pr_number: int, token: str):
    """Fetch PR head SHA and file hunks (limited)."""
    pr_url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr_number}"
    pr = gh_request("GET", pr_url, token).json()
    head_sha = (pr.get("head") or {}).get("sha")
    if not head_sha:
        raise RuntimeError("No head_sha")

    files_url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr_number}/files?per_page=100"
    hunks: List[Dict[str, Any]] = []
    url = files_url
    while url:
        r = gh_request("GET", url, token)
        for f in r.json():
            path, patch = f.get("filename"), f.get("patch")
            if not path or should_ignore_path(path):
                continue
            if not patch:
                continue 
            hunks.extend(parse_unified_hunks(patch, path))
        
        next_url = None
        link = r.headers.get("Link", "")
        if link:
            for p in [p.strip() for p in link.split(",")]:
                if 'rel="next"' in p:
                    next_url = p[p.find("<")+1:p.find(">")]
                    break
        url = next_url
    return head_sha, hunks[:MAX_HUNKS]

def save_artifact(owner: str, repo: str, pr_number: int, head_sha: str, hunks: List[Dict[str, Any]]) -> str:
    """Save hunks to S3 as JSON artifact and return the S3 key."""
    key = f"repos/{owner}/{repo}/pr-{pr_number}/{head_sha}/patch.json"
    s3.put_object(
        Bucket=ARTIFACTS_BUCKET,
        Key=key,
        Body=json.dumps({"hunks": hunks}, ensure_ascii=False).encode("utf-8"),
        ContentType="application/json",
        ServerSideEncryption="AES256"

    )
    return key

# def save_artifact(owner, repo, pr_number, head_sha, delivery_id, hunks):
#     key = f"repos/{owner}/{repo}/pr-{pr_number}/{head_sha}/patch.json"
#     s3.put_object(
#         Bucket=ARTIFACTS_BUCKET,
#         Key=key,
#         Body=json.dumps({
#             "owner": owner, "repo": repo, "pr_number": pr_number,
#             "head_sha": head_sha, "delivery_id": delivery_id,
#             "hunks": hunks
#         }, ensure_ascii=False).encode("utf-8"),
#         ContentType="application/json"
#     )
#     return key

def lambda_handler(event, context):
    
    token = get_token()
    processed = 0

    for msg in parse_messages(event):
        owner = msg.get("owner"); repo = msg.get("repo"); prn = msg.get("pr_number")
        delivery_id = msg.get("delivery_id")
        if not (owner and repo and prn and delivery_id):
            logger.info("Skip (missing fields): %s", msg)
            continue

        try:
            head_sha, hunks = enrich(owner, repo, int(prn), token)
        except Exception as e:
            logger.exception("Enrich failed for %s/%s#%s: %s", owner, repo, prn, e)
            continue

    
        if not ddb_put_once(delivery_id, head_sha):
            logger.info("Duplicate delivery+sha; skipping.")
            continue

        s3_key = None
        try:
            s3_key = save_artifact(owner, repo, int(prn), head_sha, hunks)
        except Exception:
            logger.exception("Artifact save failed (continue)")

        payload = {
            "delivery_id": delivery_id,
            "owner": owner,
            "repo": repo,
            "pr_number": prn,
            "head_sha": head_sha,
            "artifact": {"s3_bucket": ARTIFACTS_BUCKET, "s3_key": s3_key},
            "hunk_count": len(hunks),
            "policy": {"max_comments": MAX_HUNKS, "style":"concise","severity_threshold":"suggestion"},
            "ts": int(time.time())
        }
        sqs.send_message(QueueUrl=TARGET_QUEUE_URL, MessageBody=json.dumps(payload))
        processed += 1

    return {"ok": True, "processed": processed}
