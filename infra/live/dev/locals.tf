locals {
  project     = var.project
  env         = var.env
  name_prefix = "${local.project}-${local.env}" 
  tags = {
    Project     = local.project
    Environment = local.env
  }

  review_worker_image = "${module.review_worker_ecr.repository_url}:dev"
  dispatcher_image = "${module.dispatcher_ecr.repository_url}:dev"

  ecr_cfg = {
    for name, override in var.repositories :
      name => merge(var.ecr_defaults, override)
  }

  sqs_cfg = {
    for key, override in var.queues :
    key => merge(var.sqs_defaults, override)
  }

  dispatcher_ecr_cfg     = local.ecr_cfg["dispatcher_ecr"]
  worker_ecr_cfg         = local.ecr_cfg["worker_ecr"]

  review_sqs_cfg         = local.sqs_cfg["review_sqs"]
  pr_events_sqs_cfg      = local.sqs_cfg["pr_events_sqs"]

  artifacts_bucket_cfg = var.artifacts_bucket

  ddb_cfg = var.ddb

  ecs_worker_task_cfg    = var.ecs_worker_task

  webhook_api_lambda_cfg = var.webhook_api_lambda

  dispatcher_lambda_cfg = var.sqs_dispatcher_lambda

  network_cfg = var.network

  sfn_ecs_runner_cfg = var.sfn_ecs_runner

  pipe_sqs_to_sfn_cfg = var.pipe_sqs_to_sfn
}