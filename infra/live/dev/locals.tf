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

  dispatcher_ecr     = local.ecr_cfg["dispatcher_ecr"]
  worker_ecr         = local.ecr_cfg["worker_ecr"]

  review_sqs         = local.sqs_cfg["review_sqs"]
  pr_events_sqs      = local.sqs_cfg["pr_events_sqs"]

  artifacts_bucket_config = var.artifacts_bucket_config

  ecs_worker_task    = var.ecs_worker_task
}