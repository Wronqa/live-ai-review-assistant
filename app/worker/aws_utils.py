from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional
import boto3

from .logutil import setup_logger
from .config import (
    ADAPTER_BUCKET, LORA_ADAPTER_DIR,
    
)

log = setup_logger("aws-utils")

s3 = boto3.client("s3")
sm = boto3.client("secretsmanager")
sqs = boto3.client("sqs")

def is_sm_arn(v: str | None) -> bool:
    return bool(v and v.startswith("arn:aws:secretsmanager:"))

def get_secret_value_by_arn(arn: str) -> str:
    resp = sm.get_secret_value(SecretId=arn)
    return resp.get("SecretString") or resp["SecretBinary"].decode()

def env_or_secret(name: str) -> Optional[str]:
    v = os.getenv(name)
    if not v:
        return None
    if is_sm_arn(v):
        return get_secret_value_by_arn(v)
    return v

def list_all_common_prefixes(bucket: str, delimiter: str = "/") -> List[str]:
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

def list_all_objects(bucket: str, prefix: str) -> List[Dict[str, Any]]:
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

def pick_latest_prefix(prefixes: List[str]) -> str:
    if not prefixes:
        raise RuntimeError("No adapter prefixes found in S3 bucket")
    return sorted(prefixes, reverse=True)[0]

def download_latest_adapter_from_s3() -> str:
    os.makedirs(LORA_ADAPTER_DIR, exist_ok=True)
    prefixes = list_all_common_prefixes(ADAPTER_BUCKET, delimiter="/")
    latest = pick_latest_prefix(prefixes)
    log.info("Latest adapter prefix in S3: %s", latest)

    objs = list_all_objects(ADAPTER_BUCKET, latest + "/")
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

def load_hunks_from_s3(bucket: str, key: str) -> List[Dict[str, Any]]:
    obj = s3.get_object(Bucket=bucket, Key=key)
    data = json.loads(obj["Body"].read())
    hunks = data.get("hunks") or []
    if not isinstance(hunks, list):
        raise ValueError("Invalid artifact format: 'hunks' not a list")
    return hunks

