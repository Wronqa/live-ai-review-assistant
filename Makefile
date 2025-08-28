SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

ENV ?= .env

-include $(ENV)
export


TF = terraform -chdir=$(TF_DIR)

REPO_URL  = $(shell AWS_PROFILE=$(AWS_PROFILE) $(TF) output -raw review_worker_ecr_repository_url)
ECR_HOST  = $(firstword $(subst /, ,$(REPO_URL)))
AWS_REGION = $(word 4,$(subst ., ,$(ECR_HOST)))

.PHONY: info publish login-ecr build tag push clean

info:
	@echo "AWS_PROFILE = $(AWS_PROFILE)"
	@echo "TF_DIR      = $(TF_DIR)"
	@echo "APP_DIR     = $(APP_DIR)"
	@echo "IMAGE_LOCAL = $(IMAGE_LOCAL)"
	@echo "TAG         = $(TAG)"

publish: login-ecr build tag push
	@echo "Pushed: $(REPO_URL):$(TAG)"

login-ecr:
	@echo "Login to ECR $(ECR_HOST) (region $(AWS_REGION))"
	@aws ecr get-login-password --region $(AWS_REGION) --profile $(AWS_PROFILE) \
	  | docker login --username AWS --password-stdin $(ECR_HOST)

build:
	@echo "Build $(IMAGE_LOCAL):$(TAG) from $(APP_DIR)"
	@DOCKER_BUILDKIT=1 docker build -t $(IMAGE_LOCAL):$(TAG) $(APP_DIR)

tag:
	@echo "Tag -> $(REPO_URL):$(TAG)"
	@docker tag $(IMAGE_LOCAL):$(TAG) $(REPO_URL):$(TAG)

push:
	@echo "Push $(REPO_URL):$(TAG)"
	@docker push $(REPO_URL):$(TAG)

clean:
	-@docker rmi $(IMAGE_LOCAL):$(TAG) 2>/dev/null || true
