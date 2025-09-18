variable "name" {
  type        = string
  description = "Logical name prefix used for Lambda function and related resources."
}

variable "queue_arn" {
  type        = string
  description = "ARN of the source SQS queue triggering the Lambda."
}

variable "queue_url" {
  type        = string
  description = "URL of the source SQS queue triggering the Lambda."
}

variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster (if ECS integration is needed)."
}

variable "task_def_arn" {
  type        = string
  description = "ARN of the ECS task definition to run (if ECS integration is needed)."
}

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN assumed by ECS task (if ECS integration is needed)."
}

variable "execution_role_arn" {
  type        = string
  description = "IAM role ARN used by ECS tasks to pull images and publish logs (if ECS integration is needed)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all created AWS resources."
}

variable "image" {
  type        = string
  description = "ECR image URI used by the Lambda function (Image package type)."
}

variable "review_queue_url" {
  type        = string
  description = "URL of the target SQS review queue to which Lambda sends messages."
}

variable "review_queue_arn" {
  type        = string
  description = "ARN of the target SQS review queue to which Lambda sends messages."
}

variable "artifacts_bucket_name" {
  type        = string
  description = "Name of the S3 bucket used for storing artifacts."
}

variable "artifacts_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket used for storing artifacts."
}

variable "idem_table_name" {
  type        = string
  description = "Name of the DynamoDB table used for idempotency."
}

variable "idem_table_arn" {
  type        = string
  description = "ARN of the DynamoDB table used for idempotency."
}

variable "github_token_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing the GitHub token."
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the Lambda log group (in days)."
  type        = number
  default     = 14
}

variable "s3_put_sse_algorithm" {
  description = "Required SSE algorithm for S3 PutObject (AES256 or aws:kms)."
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.s3_put_sse_algorithm)
    error_message = "s3_put_sse_algorithm must be AES256 or aws:kms."
  }
}

variable "s3_put_kms_key_arn" {
  description = "KMS key ARN to require when s3_put_sse_algorithm is aws:kms."
  type        = string
  default     = null
  validation {
    condition     = var.s3_put_sse_algorithm != "aws:kms" || (var.s3_put_kms_key_arn != null && var.s3_put_kms_key_arn != "")
    error_message = "s3_put_kms_key_arn is required when s3_put_sse_algorithm is aws:kms."
  }
}

variable "batch_size" {
  type        = number
  description = "Maximum number of SQS messages per batch delivered to Lambda."
  default     = 5
}

variable "max_batching_window_seconds" {
  type        = number
  description = "Maximum batching window in seconds before invoking Lambda with a batch."
  default     = 1
}

variable "max_concurrency" {
  type        = number
  description = "Maximum number of concurrent batches being processed from the source queue."
  default     = 2
}

variable "timeout" {
  type        = number
  description = "Lambda timeout (seconds). Also used for calculating recommended SQS visibility timeout."
  default     = 20
}
