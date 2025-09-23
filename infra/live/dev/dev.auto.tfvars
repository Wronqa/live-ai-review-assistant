force_destroy = false
sse_algorithm = "AES256"

pitr_enabled  = false 

batch_size                  = 5
max_batching_window_seconds = 1
max_concurrency             = 2
lambda_timeout              = 20

memory_size                  = 256
timeout                      = 10
reserved_concurrent_executions = 2
log_retention_days           = 14

ecr_defaults = {
  image_tag_mutability       = "MUTABLE"
  scan_on_push               = true
  encryption_type            = "AES256"
  kms_key_arn                = null
  force_delete               = false
}

repositories = {
  dispatcher_ecr = {
  }

  worker_ecr = {
  }
}

sqs_defaults = {
  fifo_queue                      = false
  content_based_deduplication     = false
  visibility_timeout_seconds      = 30
  message_retention_seconds       = 345600   
  dlq_message_retention_seconds   = 1209600  
  dlq_visibility_timeout_seconds  = 30
  delay_seconds                   = 0
  receive_wait_time_seconds       = 10    
  max_message_size                = 262144   
  max_receive_count               = 2
}

queues = {
  review_sqs = {
  }
  pr_events_sqs = {
  }
}

ecs_worker_task = {
  cpu                       = 4096
  memory                    = 30720
  use_fargate_spot          = true
  enable_container_insights = true
  model_adapters_s3_arn     = "arn:aws:s3:::codegen-350m-finetune-adapters"
}

artifacts_bucket = {
  transition_days = 30
  versioning      = false
  force_destroy   = true
  sse_algorithm   = "AES256"
  kms_key_id      = null
}

ddb = {
  pk_attribute    = "pk"
  ttl_enabled     = true
  ttl_attribute   = "ttl"
  pitr_enabled    = true
  sse_enabled     = true         
}

webhook_api_lambda = {
  log_retention_days = 14
  reserved_concurrent_executions = -1
  lambda_runtime = "python3.11"
  lambda_handler = "handler.lambda_handler"
  timeout = 10
  memory_size = 256
}

sqs_dispatcher_lambda = {
  timeout = 20
  max_concurrency = 2
  max_batching_window_seconds = 1
  batch_size = 5
  s3_put_kms_key_arn = null
  log_retention_days = 14
}

network = {
  vpc_cidr = "10.42.0.0/16" 
  azs = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

sfn_ecs_runner = {
  assign_public_ip = true
  send_to_dlq = true
}

pipe_sqs_to_sfn = {
  batch_size = 1
}