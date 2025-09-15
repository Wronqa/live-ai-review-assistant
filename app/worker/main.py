import os, json, logging, sys
from typing import Any, Dict, List
import requests
import boto3

LOG_LEVEL = os.getenv("LOG_LEVEL","INFO").upper()
logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ecs-reviewer")

GITHUB_API_BASE = os.getenv("GITHUB_API_BASE","https://api.github.com")
USER_AGENT      = os.getenv("GITHUB_USER_AGENT","lara-ecs-reviewer")
GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN")
MAX_BODY_CHARS  = int(os.getenv("MAX_BODY_CHARS","250"))
IDEMPOTENCY     = os.getenv("IDEMPOTENCY","true").lower()=="true"
MARKER_PREFIX   = os.getenv("MARKER_PREFIX","lara")

s3 = boto3.client("s3")
sm = boto3.client("secretsmanager")

def get_token()->str:
    if not GITHUB_TOKEN_SECRET_ARN:
        raise RuntimeError("Missing GITHUB_TOKEN or GITHUB_TOKEN_SECRET_ARN")
    r = sm.get_secret_value(SecretId=GITHUB_TOKEN_SECRET_ARN)
    return r.get("SecretString") or r["SecretBinary"].decode()

def gh_request(method:str, url:str, token:str, **kw)->requests.Response:
    headers = kw.pop("headers",{})
    headers.setdefault("Accept","application/vnd.github+json")
    headers.setdefault("Authorization",f"Bearer {token}")
    headers.setdefault("User-Agent",USER_AGENT)
    resp = requests.request(method,url,headers=headers,timeout=float(os.getenv("HTTP_TIMEOUT_SEC","12")),**kw)
    resp.raise_for_status()
    return resp

def make_marker(delivery_id: str|None, head_sha: str|None)->str:
    parts=[]
    if delivery_id: parts.append(f"delivery_id={delivery_id}")
    if head_sha:    parts.append(f"head_sha={head_sha}")
    return f"<!-- {MARKER_PREFIX}:{' '.join(parts) if parts else 'no-id'} -->"

def existing_marker(owner:str,repo:str,pr:int,token:str,delivery_id:str,head_sha:str)->bool:
    if not IDEMPOTENCY: return False
    marker = make_marker(delivery_id, head_sha).strip("<!-- ").strip(" -->")
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr}/reviews?per_page=100"
    while url:
        r = gh_request("GET", url, token)
        for rev in r.json():
            body = rev.get("body") or ""
            if MARKER_PREFIX in body and all(p in body for p in marker.split()):
                return True
        link = r.headers.get("Link",""); nxt=None
        if link:
            for p in [p.strip() for p in link.split(",")]:
                if 'rel="next"' in p: nxt = p[p.find("<")+1:p.find(">")]
        url = nxt
    return False

def mock_suggest(h: Dict[str,Any])->str:
    path = h.get("file_path",""); patch = h.get("patch_hunk","")
    msg="Consider adding tests and improving naming for readability."
    if path.endswith((".py",".ts",".tsx",".js")) and ("print(" in patch or "console.log(" in patch):
        msg="Consider removing debug prints or guard them behind a verbose flag."
    return msg[:MAX_BODY_CHARS]

def pick_line(h: Dict[str,Any])->int:
    new_start=int(h.get("new_start") or 1); new_len=int(h.get("new_lines") or 1)
    return new_start if new_len<=1 else new_start+(new_len//2)

def load_hunks_from_s3(bucket: str, key: str) -> List[Dict[str,Any]]:
    """Download artifact JSON from S3 and return hunks list."""
    obj = s3.get_object(Bucket=bucket, Key=key)
    data = json.loads(obj["Body"].read())
    hunks = data.get("hunks") or []
    if not isinstance(hunks, list):
        raise ValueError("Invalid artifact format: 'hunks' not a list")
    return hunks

def create_summary(owner,repo,pr,token,delivery_id,head_sha,count_comments,count_hunks):
    body = f"Automated review (ecs): {count_comments} suggestion(s) across {count_hunks} hunk(s).\n\n{make_marker(delivery_id,head_sha)}"
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr}/reviews"
    return gh_request("POST", url, token, json={"event":"COMMENT","body":body}).json()

def post_inline(owner,repo,pr,token,head_sha,hunk,text):
    url = f"{GITHUB_API_BASE}/repos/{owner}/{repo}/pulls/{pr}/comments"
    payload = {"body": text, "path": hunk["file_path"], "line": pick_line(hunk), "side": "RIGHT", "commit_id": head_sha}
    return gh_request("POST", url, token, json=payload).json()

def handle_event(evt: Dict[str,Any])->None:
    owner=evt.get("owner"); repo=evt.get("repo"); pr=evt.get("pr_number")
    head_sha=evt.get("head_sha"); delivery_id=evt.get("delivery_id")
    artifact=(evt.get("artifact") or {})
    bucket=artifact.get("s3_bucket"); key=artifact.get("s3_key")

    if not (owner and repo and pr and head_sha and bucket and key):
        raise ValueError("Missing required fields (owner/repo/pr/head_sha/artifact)")

    token = get_token()

    if IDEMPOTENCY and existing_marker(owner,repo,int(pr),token,delivery_id,head_sha):
        log.info("Duplicate marker found, skip"); 
        return

    hunks = load_hunks_from_s3(bucket, key)
    suggestions=[{"h":h,"t":mock_suggest(h)} for h in hunks]

    rev=create_summary(owner,repo,int(pr),token,delivery_id,head_sha,len(suggestions),len(hunks))
    posted=0
    for s in suggestions:
        try:
            post_inline(owner,repo,int(pr),token,head_sha,s["h"],s["t"])
            posted+=1
        except Exception:
            log.exception("Inline failed for %s", s["h"].get("file_path"))
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
        handle_event(evt)
    except Exception as e:
        log.exception("Processing failed: %s", e)
        sys.exit(1)

if __name__ == "__main__":
    main()
