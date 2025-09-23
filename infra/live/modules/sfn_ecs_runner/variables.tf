variable "name" {
  type        = string
  description = "Name prefix used for resources created by this module."
}

variable "tags" {
  description = "Common tags applied to all created resources."
  type        = map(string)
  default     = {}
}

variable "task_definition_arn" {
  type        = string
  description = "ARN of the ECS task definition to run."
}

variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the task will be launched."
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster where the task will be launched."
}

variable "task_execution_role_arn" {
  type        = string
  description = "ARN of the IAM role used by ECS to pull images and publish logs."
}

variable "task_role_arn" {
  type        = string
  description = "ARN of the IAM role assumed by the running ECS task."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs where the ECS task will run."
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs attached to the ECS task ENIs."
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Whether to assign a public IP to ECS task ENIs."
}

variable "container_name" {
  type        = string
  default     = "ecs-reviewer"
  description = "Logical name of the container within the ECS task."
}

variable "review_sqs_dlq_arn" {
  type        = string
  description = "ARN of the SQS Dead Letter Queue used by Pipes and/or Step Functions Catch."
}

variable "review_sqs_dlq_url" {
  type        = string
  description = "URL of the SQS Dead Letter Queue used by Pipes and/or Step Functions Catch."
}

variable "send_to_dlq" {
  description = "If true, messages go to the DLQ. If false, messages go to the main SQS queue."
  type        = bool
  default     = true
}

variable "review_sqs_arn" {
  description = "ARN of the main SQS queue."
  type        = string
}

variable "review_sqs_url" {
  description = "URL of the main SQS queue."
  type        = string
}
