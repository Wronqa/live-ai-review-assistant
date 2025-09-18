variable "name" {
  type        = string
  description = "Base name/prefix for ECS resources (cluster, roles, log group, task family)."
}

variable "image" {
  type        = string
  description = "Full container image reference (e.g., ECR URL with tag) used for the ECS task container."
}

variable "cpu" {
  type        = number
  default     = 512
  description = "Amount of CPU units to allocate for the ECS task (must match Fargate valid CPU values)."
}

variable "memory" {
  type        = number
  default     = 1024
  description = "Amount of memory (in MB) to allocate for the ECS task (must match valid Fargate memory values for the chosen CPU)."
}

variable "env" {
  type        = map(string)
  default     = {}
  description = "Plain-text environment variables passed to the ECS container."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all ECS-related resources."
}

variable "artifact_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket that the ECS task is allowed to read artifacts from (GetObject permissions)."
}

variable "enable_container_insights" {
  type        = bool
  default     = true
  description = "Whether to enable CloudWatch Container Insights on the ECS cluster."
}

variable "use_fargate_spot" {
  type        = bool
  default     = true
  description = "Whether to attach the FARGATE_SPOT capacity provider in addition to FARGATE and use it in the default strategy."
}

variable "log_group_name" {
  type        = string
  default     = null
  description = "Override CloudWatch Log Group name. Defaults to /ecs/<name>."
}

variable "task_role_name" {
  type        = string
  default     = null
  description = "Custom name for the ECS task role. If null, defaults to <name>-task-role."
}

variable "task_s3_policy_name" {
  type        = string
  default     = null
  description = "Custom name for the ECS task inline S3 policy. If null, defaults to <name>-task-s3-policy."
}

variable "model_adapters_s3_arn" {
  type        = string
  description = "ARN zasobu S3 (bucket lub prefix) zawierającego najnowsze LoRA adaptery modelu. Używane przez ECS task do pobierania adapterów w runtime."
}
