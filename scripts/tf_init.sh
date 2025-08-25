#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:=default}"
export AWS_PROFILE

BUCKET="$(terraform -chdir=infra/bootstrap output -raw state_bucket)"
LOCK="$(terraform -chdir=infra/bootstrap output -raw lock_table)"

terraform -chdir=infra/live/dev init -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=live/dev/terraform.tfstate" \
  -backend-config="region=eu-north-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"