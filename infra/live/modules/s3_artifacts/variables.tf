variable "name_prefix" {
  description = "Prefix for the S3 bucket name. A random suffix will be appended to ensure uniqueness."
  type        = string
}

variable "transition_days" {
  description = "Number of days after which objects transition to a colder storage class."
  type        = number
  default     = 30
}

variable "versioning" {
  description = "Whether to enable S3 versioning. Recommended to keep it enabled for safety."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of common tags to apply to all created resources."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Force bucket deletion even if it contains objects. Use with caution (handy in dev/test)."
  type        = bool
  default     = false
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm to apply. Supported values: AES256 or aws:kms."
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be either AES256 or aws:kms."
  }
}

variable "kms_key_id" {
  description = "KMS key ARN/ID to use when sse_algorithm is aws:kms."
  type        = string
  default     = null
  validation {
    condition     = var.sse_algorithm != "aws:kms" || (var.kms_key_id != null && var.kms_key_id != "")
    error_message = "kms_key_id is required when sse_algorithm is aws:kms."
  }
}
