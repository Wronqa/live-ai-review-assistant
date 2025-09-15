variable "project" { 
    type = string
    default = "lara" 
}
variable "env"     { 
    type = string
    default = "dev" 
}

variable "force_destroy" {
    type = bool
}

variable "sse_algorithm"    { 
    type = string 
}

variable "pitr_enabled" { 
    type = bool
}

variable "batch_size" {
  type        = number
  description = "Maximum number of SQS messages per batch delivered to the Lambda function."
  default     = 5
  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 10
    error_message = "batch_size must be between 1 and 10 (AWS limit)."
  }
}

variable "max_batching_window_seconds" {
  type        = number
  description = "Maximum amount of time (in seconds) to gather records before invoking the Lambda with a batch."
  default     = 1
  validation {
    condition     = var.max_batching_window_seconds >= 0 && var.max_batching_window_seconds <= 300
    error_message = "max_batching_window_seconds must be between 0 and 300 (AWS limit)."
  }
}

variable "max_concurrency" {
  type        = number
  description = "Maximum number of concurrent batches that the Event Source Mapping (ESM) can process in parallel."
  default     = 2
  validation {
    condition     = var.max_concurrency >= 1
    error_message = "max_concurrency must be greater than or equal to 1."
  }
}

variable "lambda_timeout" {
  type        = number
  description = "Timeout (in seconds) for the Lambda function. Also used to calculate recommended SQS visibility timeout."
  default     = 20
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "lambda_timeout must be between 1 and 900 seconds (AWS Lambda limit)."
  }
}

variable "memory_size" {
  type        = number
  default     = 256
  description = "Amount of memory (in MB) allocated to the Lambda function. Also affects allocated vCPU."
}

variable "timeout" {
  type        = number
  default     = 10
  description = "Maximum execution time for the Lambda function (in seconds). The function will be terminated if it exceeds this time."
}

variable "reserved_concurrent_executions" {
  type        = number
  default     = 2
  description = "Concurrency limit for the Lambda function. Set to -1 for unlimited concurrency."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "Number of days to retain CloudWatch Logs for the Lambda function."
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
  })
  default = {
    cpu                       = 1024
    memory                    = 2048
    use_fargate_spot          = true
    enable_container_insights = true
  }
  description = "Default ECS task configuration (can be overridden per environment using task overrides)."
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

  default = {
    fifo_queue                      = false
    content_based_deduplication     = false
    visibility_timeout_seconds      = 30
    message_retention_seconds       = 345600   
    dlq_message_retention_seconds   = 1209600  
    dlq_visibility_timeout_seconds  = 30
    delay_seconds                   = 0
    receive_wait_time_seconds       = 10       
    max_message_size                = 262144   
    max_receive_count               = 5
  }

  description = "Default SQS settings for queues in this environment."
}


variable "queues" {
  type        = map(any)
  default     = {}
  description = "Per-queue overrides. Keys are logical names (e.g., review, pr)."
}