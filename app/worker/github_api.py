from __future__ import annotations

import re
from typing import Any, Dict
from datetime import datetime

import jwt 
import requests

from .logutil import setup_logger
from .aws_utils import get_secret_value_by_arn
from .config import (
    MARKER_PREFIX,
    GITHUB_API_BASE,
    USER_AGENT,
    HTTP_TIMEOUT_SEC,
    GITHUB_TOKEN_SECRET_ARN,            
    GITHUB_APP_PRIVATE_KEY_SECRET_ARN,   
    GITHUB_APP_INSTALLATION_ID_ARN,
    GITHUB_APP_ID_ARN 
)
from .config import utc_ts

log = setup_logger("github")

def _resolve_numeric_id_from_arn_env(arn: str) -> str:
    raw = (get_secret_value_by_arn(arn) or "").strip()

    if raw.isdigit():
        return raw

    m = re.search(r"\d+", raw)
    if m:
        num = m.group(0)
        log.warning("%s value is not a pure number; using extracted digits: %s", name, num)
        return num

    raise ValueError(f"Secret referenced by {name} must contain a numeric ID; got: {raw!r}")


def _load_github_app_private_key_pem() -> str:
    if not GITHUB_APP_PRIVATE_KEY_SECRET_ARN or not GITHUB_APP_PRIVATE_KEY_SECRET_ARN.startswith("arn:aws:secretsmanager:"):
        raise ValueError("GITHUB_APP_PRIVATE_KEY_SECRET_ARN must be a Secrets Manager ARN")
    pem = get_secret_value_by_arn(GITHUB_APP_PRIVATE_KEY_SECRET_ARN)
    if not pem or "BEGIN RSA PRIVATE KEY" not in pem and "BEGIN PRIVATE KEY" not in pem:
        log.warning("Private key fetched, but it doesn't look like a PEM. Ensure the secret stores the PEM text.")
    return pem

def _build_app_jwt(app_id_num: str, private_key_pem: str) -> str:
    now = utc_ts()
    payload = {"iat": now - 60, "exp": now + 9 * 60, "iss": int(app_id_num)}
    return jwt.encode(payload, private_key_pem, algorithm="RS256")


def _fetch_installation_token(app_jwt: str, installation_id_num: str) -> Dict[str, Any]:
    url = f"{GITHUB_API_BASE}/app/installations/{installation_id_num}/access_tokens"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {app_jwt}",
        "User-Agent": USER_AGENT,
    }
    resp = requests.post(url, headers=headers, timeout=HTTP_TIMEOUT_SEC)
    resp.raise_for_status()
    return resp.json()


_app_token_ctx: Dict[str, Any] = {"token": None, "exp_ts": 0}

def get_github_app_installation_token() -> str:
    if _app_token_ctx["token"] and _app_token_ctx["exp_ts"] - utc_ts() > 60:
        return _app_token_ctx["token"]

    app_id = _resolve_numeric_id_from_arn_env(GITHUB_APP_ID_ARN)
    installation_id = _resolve_numeric_id_from_arn_env(GITHUB_APP_INSTALLATION_ID_ARN)
    pem = _load_github_app_private_key_pem()

    app_jwt = _build_app_jwt(app_id, pem)
    data = _fetch_installation_token(app_jwt, installation_id)

    token = data["token"]
    exp_ts = int(datetime.fromisoformat(data["expires_at"].replace("Z", "+00:00")).timestamp())
    _app_token_ctx.update({"token": token, "exp_ts": exp_ts})
    return token

def get_token() -> str:
    try:
        t = get_github_app_installation_token()
        log.info("GitHub auth mode: app")
        return t
    except Exception as e:
        log.warning("GitHub App auth failed; checking PAT ARN fallback: %s", e)

    if GITHUB_TOKEN_SECRET_ARN:
        if not GITHUB_TOKEN_SECRET_ARN.startswith("arn:aws:secretsmanager:"):
            raise ValueError("GITHUB_TOKEN_SECRET_ARN must be a Secrets Manager ARN")
        pat = (get_secret_value_by_arn(GITHUB_TOKEN_SECRET_ARN) or "").strip()
        if not pat:
            raise RuntimeError("PAT secret resolved from GITHUB_TOKEN_SECRET_ARN is empty")
        log.info("GitHub auth mode: pat")
        return pat

    raise RuntimeError("Missing credentials: set ARNs for App (ID, INSTALLATION_ID, PRIVATE_KEY) or PAT.")

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
