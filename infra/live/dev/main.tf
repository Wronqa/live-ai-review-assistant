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

  azs = local.network_cfg.azs
  vpc_cidr = local.network_cfg.vpc_cidr
}

module "pr_events_queue" {
  source = "../modules/pr_events_sqs"

  name =  "${local.name_prefix}-pr-events"

  fifo_queue                  = local.pr_events_sqs_cfg.fifo_queue
  content_based_deduplication = local.pr_events_sqs_cfg.content_based_deduplication

  visibility_timeout_seconds      = local.pr_events_sqs_cfg.visibility_timeout_seconds
  message_retention_seconds       = local.pr_events_sqs_cfg.message_retention_seconds
  dlq_message_retention_seconds   = local.pr_events_sqs_cfg.dlq_message_retention_seconds
  dlq_visibility_timeout_seconds  = local.pr_events_sqs_cfg.dlq_visibility_timeout_seconds
  delay_seconds                   = local.pr_events_sqs_cfg.delay_seconds
  receive_wait_time_seconds       = local.pr_events_sqs_cfg.receive_wait_time_seconds
  max_message_size                = local.pr_events_sqs_cfg.max_message_size
  max_receive_count               = local.pr_events_sqs_cfg.max_receive_count

  tags = local.tags
}

module "review_queue" {
  source = "../modules/review_sqs"

  name =  "${local.name_prefix}-review-events"

  fifo_queue                  = local.review_sqs_cfg.fifo_queue
  content_based_deduplication = local.review_sqs_cfg.content_based_deduplication

  visibility_timeout_seconds      = local.review_sqs_cfg.visibility_timeout_seconds
  message_retention_seconds       = local.review_sqs_cfg.message_retention_seconds
  dlq_message_retention_seconds   = local.review_sqs_cfg.dlq_message_retention_seconds
  dlq_visibility_timeout_seconds  = local.review_sqs_cfg.dlq_visibility_timeout_seconds
  delay_seconds                   = local.review_sqs_cfg.delay_seconds
  receive_wait_time_seconds       = local.review_sqs_cfg.receive_wait_time_seconds
  max_message_size                = local.review_sqs_cfg.max_message_size
  max_receive_count               = local.review_sqs_cfg.max_receive_count

  tags = local.tags
}

module "secrets" {
  source = "../modules/secrets"

  names = [
    "lara/dev/github/webhook_secret",  
    "lara/dev/github/token",
    "lara/dev/github/app/id",
    "lara/dev/github/installation/id",
    "lara/dev/github/app/token",          
  ]
  tags = local.tags
}

module "webhook_api" {
  source = "../modules/webhook_api"

  name = "${local.name_prefix}-webhook"
  lambda_source_dir = "${path.root}/../../../app/webhook"

  webhook_secret_arn = module.secrets.arns["lara/dev/github/webhook_secret"]

  memory_size = local.webhook_api_lambda_cfg.memory_size
  timeout = local.webhook_api_lambda_cfg.timeout
  lambda_handler = local.webhook_api_lambda_cfg.lambda_handler
  lambda_runtime = local.webhook_api_lambda_cfg.lambda_runtime
  reserved_concurrent_executions = local.webhook_api_lambda_cfg.reserved_concurrent_executions
  log_retention_days = local.webhook_api_lambda_cfg.log_retention_days

  sqs_queue_arn = module.pr_events_queue.queue_arn
  sqs_queue_url = module.pr_events_queue.queue_url

  tags = local.tags
}

module "sm_read_webhook" {
  source      = "../modules/policy_sm_read"
  name        = "${local.name_prefix}-sm-read-webhook"
  secret_arns = [module.secrets.arns["lara/dev/github/token"], module.secrets.arns["lara/dev/github/webhook_secret"]]
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_sm_read_webhook" {
  role       = module.webhook_api.role_name
  policy_arn = module.sm_read_webhook.arn
}

module "dispatcher_ecr" {
  source = "../modules/dispatcher_ecr_repo"

  name = "${local.name_prefix}-review-dispatcher"

  image_tag_mutability       = local.dispatcher_ecr_cfg.image_tag_mutability
  scan_on_push               = local.dispatcher_ecr_cfg.scan_on_push
  encryption_type            = local.dispatcher_ecr_cfg.encryption_type
  kms_key_arn                = local.dispatcher_ecr_cfg.kms_key_arn
  force_delete               = local.dispatcher_ecr_cfg.force_delete

  tags = local.tags
}

module "review_worker_ecr" {
  source = "../modules/worker_ecr_repo"

  name = "${local.name_prefix}-review-worker"

  image_tag_mutability       = local.worker_ecr_cfg.image_tag_mutability
  scan_on_push               = local.worker_ecr_cfg.scan_on_push
  encryption_type            = local.worker_ecr_cfg.encryption_type
  kms_key_arn                = local.worker_ecr_cfg.kms_key_arn
  force_delete               = local.worker_ecr_cfg.force_delete

  tags = local.tags
}

module "ecs_review_worker" {
  source = "../modules/ecs_task"

  name           = "${local.name_prefix}-review-worker"
  image          = local.review_worker_image

  artifact_bucket_arn = module.artifacts.bucket_arn

  cpu    = local.ecs_worker_task_cfg.cpu
  memory = local.ecs_worker_task_cfg.memory
  model_adapters_s3_arn = local.ecs_worker_task_cfg.model_adapters_s3_arn

  env = {
    APP_ENV   = local.env
    LOG_LEVEL = "WARNING"
    GITHUB_TOKEN_SECRET_ARN              = module.secrets.arns["lara/dev/github/token"]
    GITHUB_APP_ID                        = module.secrets.arns["lara/dev/github/app/id"]
    GITHUB_APP_INSTALLATION_ID           = module.secrets.arns["lara/dev/github/installation/id"]
    GITHUB_APP_PRIVATE_KEY_SECRET_ARN    = module.secrets.arns["lara/dev/github/app/token"]

    GITHUB_API_BASE            = "https://api.github.com"
    GITHUB_USER_AGENT          = "lara-review-worker"
    
  }

  tags = local.tags
}

module "sm_read_worker" {
  source      = "../modules/policy_sm_read"
  name        = "${local.name_prefix}-sm-read-worker"
  secret_arns = [
    module.secrets.arns["lara/dev/github/token"], 
    module.secrets.arns["lara/dev/github/webhook_secret"],
    module.secrets.arns["lara/dev/github/app/id"],
    module.secrets.arns["lara/dev/github/app/token"],
    module.secrets.arns["lara/dev/github/installation/id"],
  ]
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_sm_read_worker" {
  role       = module.ecs_review_worker.task_role_name
  policy_arn = module.sm_read_worker.arn
}

module "sqs_dispatcher" {
  source = "../modules/sqs_dispatcher"

  name            = "${local.name_prefix}-sqs-dispatcher"

  image           = local.dispatcher_image

  queue_arn       = module.pr_events_queue.queue_arn
  queue_url       = module.pr_events_queue.queue_url

  review_queue_url = module.review_queue.queue_url
  review_queue_arn = module.review_queue.queue_arn

  cluster_arn        = module.ecs_review_worker.cluster_arn
  task_def_arn       = module.ecs_review_worker.task_definition_arn
  
  task_role_arn      = module.ecs_review_worker.task_role_arn
  execution_role_arn = module.ecs_review_worker.execution_role_arn

  artifacts_bucket_name = module.artifacts.bucket_name
  artifacts_bucket_arn = module.artifacts.bucket_arn

  idem_table_name = module.idem.table_name
  idem_table_arn  = module.idem.table_arn

  github_token_arn   = module.secrets.arns["lara/dev/github/token"]

  s3_put_sse_algorithm = local.artifacts_bucket_cfg.sse_algorithm

  batch_size = local.dispatcher_lambda_cfg.batch_size
  max_batching_window_seconds = local.dispatcher_lambda_cfg.max_batching_window_seconds
  max_concurrency = local.dispatcher_lambda_cfg.max_concurrency
  timeout = local.dispatcher_lambda_cfg.timeout

  tags = local.tags
}

module "sm_read_dispatcher" {
  source      = "../modules/policy_sm_read"
  name        = "${local.name_prefix}-sm-read-dispatcher"
  secret_arns = [module.secrets.arns["lara/dev/github/token"]]
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_sm_read_dispatcher" {
  role       = module.sqs_dispatcher.role_name
  policy_arn = module.sm_read_dispatcher.arn
}

data "aws_secretsmanager_secret" "gh_token" {
  name = "lara/dev/github/token"
}

module "artifacts" {
  source         = "../modules/s3_artifacts"
  name_prefix    = "${local.name_prefix}-artifacts"

  transition_days = local.artifacts_bucket_cfg.transition_days
  versioning      = local.artifacts_bucket_cfg.versioning
  force_destroy   = local.artifacts_bucket_cfg.force_destroy
  sse_algorithm   = local.artifacts_bucket_cfg.sse_algorithm
  kms_key_id      = local.artifacts_bucket_cfg.kms_key_id

  tags           = local.tags
}

module "idem" {
  source        = "../modules/dynamodb_idempotency"
  table_name    = "${local.name_prefix}-idem"

  pk_attribute    = local.ddb_cfg.pk_attribute
  ttl_enabled     = local.ddb_cfg.ttl_enabled
  ttl_attribute   = local.ddb_cfg.ttl_attribute
  pitr_enabled    = local.ddb_cfg.pitr_enabled
  sse_enabled     = local.ddb_cfg.sse_enabled         

  tags          = local.tags
}

module "pipe_review_to_ecs" {
  source              = "../modules/pipes_sqs_to_ecs"

  name                = "lara-dev-review-to-ecs"
  source_queue_arn    = module.review_queue.queue_arn
  cluster_arn         = module.ecs_review_worker.cluster_arn
  task_definition_arn = module.ecs_review_worker.task_definition_arn
  subnet_ids          = module.network.public_subnet_ids
  security_group_ids  = [module.network.ecs_sg_id]

  execution_role_arn = module.ecs_review_worker.execution_role_arn
  task_role_arn = module.ecs_review_worker.task_role_arn

  assign_public_ip    = local.pipe_sqs_to_ecs_cfg.assign_public_ip
  batch_size          = local.pipe_sqs_to_ecs_cfg.batch_size
  container_name      = module.ecs_review_worker.container_name
}
