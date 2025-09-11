variable "table_name" {
  description = "DynamoDB table name for idempotency keys."
  type        = string
}

variable "pk_attribute" {
  description = "Primary key attribute name."
  type        = string
  default     = "pk"
}

variable "ttl_attribute" {
  description = "TTL attribute name."
  type        = string
  default     = "ttl"
}

variable "ttl_enabled" {
  description = "Enable DynamoDB TTL (automatic expiration of items based on a specified attribute)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

variable "sse_enabled" {
  description = "Enable server-side encryption at rest."
  type        = bool
  default     = true
}

variable "sse_kms_key_arn" {
  description = "Custom KMS key ARN for SSE (leave null to use AWS owned key)."
  type        = string
  default     = null
}

variable "pitr_enabled" {
  description = "Enable point-in-time recovery (up to 35 days back)."
  type        = bool
  default     = true
}