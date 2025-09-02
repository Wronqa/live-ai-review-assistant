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

module "ecs_review_worker" {
  source = "../modules/ecs_task"

  name           = "${local.name_prefix}-review-worker"
  image          = local.review_worker_image

  subnet_ids     = module.network.public_subnet_ids
  security_group = module.network.ecs_sg_id

  cpu    = 256
  memory = 512

  env = {
    APP_ENV   = local.env
    LOG_LEVEL = "WARNING"
  }

  tags = local.tags
}

module "sqs_dispatcher" {
  source = "../modules/sqs_dispatcher"

  name            = "${local.name_prefix}-sqs-dispatcher"
  lambda_src_dir  = "${path.root}/../../../lambda/dispatcher"

  queue_arn       = module.pr_events_queue.queue_arn
  queue_url       = module.pr_events_queue.queue_url

  cluster_arn        = module.ecs_review_worker.cluster_arn
  task_def_arn       = module.ecs_review_worker.task_definition_arn
  subnet_ids         = module.ecs_review_worker.subnet_ids
  security_group     = module.ecs_review_worker.security_group
  task_role_arn      = module.ecs_review_worker.task_role_arn
  execution_role_arn = module.ecs_review_worker.execution_role_arn

  tags = local.tags
}