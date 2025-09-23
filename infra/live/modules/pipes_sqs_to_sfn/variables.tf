variable "name" {
  description = "Name of the resource."
  type        = string
}

variable "source_queue_arn" {
  description = "ARN of the source SQS queue."
  type        = string
}

variable "batch_size" {
  description = "Number of messages to process in a single batch."
  type        = number
  default     = 1
}

variable "container_name" {
  description = "Name of the ECS container."
  type        = string
  default     = "ecs-reviewer"
}

variable "tags" {
  description = "Common tags for resources."
  type        = map(string)
  default     = {}
}

variable "sfn_runner_arn" {
  description = "ARN of the Step Functions runner."
  type        = string
}
