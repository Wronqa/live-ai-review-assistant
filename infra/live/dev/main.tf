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
      Project     = "lara"
      Environment = "dev"
    }
  }
}

module "network" {
  source = "../modules/network"
  name = "lara-dev"
}

module "pr_events_queue" {
  source = "../modules/sqs"

  name = "lara-dev-pr-events"

  tags = {
    Project     = "lara"
    Environment = "dev"
  }
}

module "secrets" {
  source = "../modules/secrets"

  names = [
    "lara/dev/github/webhook_secret",  
    "lara/dev/github/token"          
  ]

  tags = {
    Project     = "lara"
    Environment = "dev"
  }
}

module "webhook_api" {
  source = "../modules/webhook_api"

  name              = "lara-dev-webhook"
  env               = "dev"
  lambda_source_dir = "${path.root}/../../../lambda/webhook"

  webhook_secret_id = module.secrets.arns["lara/dev/github/webhook_secret"]
  github_token_id   = module.secrets.arns["lara/dev/github/token"]

  sqs_queue_arn = module.pr_events_queue.queue_arn
  sqs_queue_url = module.pr_events_queue.queue_url

  tags = {
    Project     = "lara"
    Environment = "dev"
  }
}

module "review_worker_ecr" {
  source = "../modules/ecr_repo"

  name = "lara-dev-review-worker"

  tags = {
    Project     = "lara"
    Environment = "dev"
  }
}