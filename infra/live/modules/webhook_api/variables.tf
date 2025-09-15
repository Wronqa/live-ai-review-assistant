variable "name" {
  type        = string
  description = "Unique name for the resource (Lambda, IAM, API Gateway)."
}

variable "lambda_source_dir" {
  type        = string
  description = "Path to the directory containing the Lambda source code (will be packaged into a ZIP)."
}

variable "memory_size" {
  type        = number
  default     = 256
  description = "Amount of memory (MB) allocated to the Lambda function."
}

variable "timeout" {
  type        = number
  default     = 10
  description = "Maximum execution time for the Lambda function (in seconds)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Set of tags applied to all resources."
}

variable "webhook_secret_arn" {
  type        = string
  description = "ARN of the secret in AWS Secrets Manager containing the webhook key."
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS queue where the Lambda function will send messages."
}

variable "sqs_queue_url" {
  type        = string
  description = "URL of the SQS queue used in the Lambda environment variables."
}

variable "lambda_handler" {
  type        = string
  default     = "handler.lambda_handler"
  description = "Entry point (handler) of the Lambda in the format file.method."
}

variable "lambda_runtime" {
  type        = string
  default     = "python3.11"
  description = "Lambda runtime, e.g., python3.11, nodejs18.x, etc."
}

variable "reserved_concurrent_executions" {
  type        = number
  default     = -1
  description = "Concurrency limit for the Lambda function (-1 = no limit)."
}

variable "log_retention_days" {
  type        = number
  default     = 14
  description = "Retention period for the Lambda CloudWatch log group (in days)."
}
