from __future__ import annotations
from typing import Any, Dict, List

from .logutil import setup_logger
from .github_api import gh_request, make_marker
from .config import GITHUB_API_BASE, IDEMPOTENCY, MARKER_PREFIX, MAX_HUNKS_LIMIT
from .model_io import suggest

log = setup_logger("review")

def pick_line(h: Dict[str, Any]) -> int:
    new_start = int(h.get("new_start") or 1)
    new_len = int(h.get("new_lines") or 1)
    return new_start if new_len <= 1 else new_start + (new_len // 2)

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

def limit_hunks(hunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    if MAX_HUNKS_LIMIT and len(hunks) > MAX_HUNKS_LIMIT:
        return hunks[:MAX_HUNKS_LIMIT]
    return hunks

def prepare_comments(hunks: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [{"h": h, "t": suggest(h)} for h in hunks]
