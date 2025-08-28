terraform {
  required_version = ">= 1.6"
  required_providers { 
    aws = { source = "hashicorp/aws", version = "~> 5.0" } 
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      Project     = local.project
      Environment = local.env
    }
  }
}

module "network" {
  source = "../modules/network"
  name = "${local.name_prefix}"
}

module "pr_events_queue" {
  source = "../modules/sqs"

  name =  "${local.name_prefix}-pr-events"

  tags = local.tags
}

module "secrets" {
  source = "../modules/secrets"

  names = [
    "lara/dev/github/webhook_secret",  
    "lara/dev/github/token"          
  ]

  tags = local.tags
}

module "webhook_api" {
  source = "../modules/webhook_api"

  name = "${local.name_prefix}-webhook"
  env               = local.env
  lambda_source_dir = "${path.root}/../../../lambda/webhook"

  webhook_secret_id = module.secrets.arns["lara/dev/github/webhook_secret"]
  github_token_id   = module.secrets.arns["lara/dev/github/token"]

  sqs_queue_arn = module.pr_events_queue.queue_arn
  sqs_queue_url = module.pr_events_queue.queue_url

  tags = local.tags
}

module "review_worker_ecr" {
  source = "../modules/ecr_repo"

  name = "${local.name_prefix}-review-worker"

  tags = local.tags
}