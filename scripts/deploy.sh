#!/usr/bin/env bash

terraform -chdir=infra/live/dev plan
terraform -chdir=infra/live/dev apply -auto-approve