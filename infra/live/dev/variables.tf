variable "project" { 
    type = string
    default = "lara" 
}
variable "env"     { 
    type = string
    default = "dev" 
}

variable "ecr_defaults" {
  type = object({
    image_tag_mutability       = string
    scan_on_push               = bool
    encryption_type            = string
    kms_key_arn                = string
    force_delete               = bool
  })
}

variable "repositories" {
  type    = map(any)
  default = {}
}

variable "ecs_worker_task" {
  type = object({
    cpu                       = number
    memory                    = number
    use_fargate_spot          = bool
    enable_container_insights = bool
    model_adapters_s3_arn     = string
  })

  description = "ECS task configuration. Wartości należy ustawić w plikach *.auto.tfvars (np. dev.auto.tfvars, prod.auto.tfvars)."
}

variable "sqs_defaults" {
  type = object({
    fifo_queue                      = bool
    content_based_deduplication     = bool
    visibility_timeout_seconds      = number
    message_retention_seconds       = number
    dlq_message_retention_seconds   = number
    dlq_visibility_timeout_seconds  = number
    delay_seconds                   = number
    receive_wait_time_seconds       = number
    max_message_size                = number
    max_receive_count               = number
  })

  description = "Default SQS settings for queues in this environment."
}

variable "queues" {
  type        = map(any)
  default     = {}
  description = "Per-queue overrides. Keys are logical names (e.g., review, pr)."
}

variable "artifacts_bucket" {
  description = "S3 bucket configuration (defaults can be overridden per environment)."
  type = object({
    transition_days   = number
    versioning        = bool
    force_destroy     = bool
    sse_algorithm     = string
    kms_key_id        = string
  })
}

variable "ddb" {
  description = "DynamoDB table configuration (override per environment in *.auto.tfvars)."
  type = object({
    pk_attribute    = optional(string, "pk")
    ttl_attribute   = optional(string, "ttl")
    ttl_enabled     = optional(bool,   false)
    sse_enabled     = optional(bool,   true)
    pitr_enabled    = optional(bool,   true)
  })
}

variable "webhook_api_lambda" {
  type = object({
    memory_size                  = number
    timeout                      = number
    lambda_handler               = string
    lambda_runtime               = string
    reserved_concurrent_executions = number
    log_retention_days           = number
  })
  
  description = "Configuration for the webhook API Lambda function (memory allocation, timeout, handler, runtime, concurrency, and log retention)."
}

variable "sqs_dispatcher_lambda" {
  type = object({
    timeout                      = number
    max_concurrency              = number
    max_batching_window_seconds  = number
    batch_size                   = number
    s3_put_kms_key_arn           = optional(string, null)
    log_retention_days           = number
  })
  
  description = "Configuration for the sql dispatcher Lambda function (memory allocation, timeout, handler, runtime, concurrency, and log retention)."
}

variable "network" {
  type = object({
    vpc_cidr = string
    azs      = list(string)
  })

  description = "Network configuration: VPC CIDR block, availability zones, and default tags."
}

variable "sfn_ecs_runner"{
  type = object({
    assign_public_ip = bool
    send_to_dlq = bool
  })
}

variable "pipe_sqs_to_sfn" {
  type = object({
    batch_size       = number
  })

  description = "Configuration for the SQS → Step Functions pipe, including batch size for messages polled from the source queue."
}


