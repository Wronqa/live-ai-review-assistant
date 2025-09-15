variable "name" {
  type        = string
  description = "Unique name of the ECR repository."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the ECR repository and related resources."
}

variable "image_tag_mutability" {
  type        = string
  default     = "IMMUTABLE"
  description = "Whether image tags are mutable or immutable. Allowed values: MUTABLE, IMMUTABLE."
}

variable "scan_on_push" {
  type        = bool
  default     = true
  description = "Enable vulnerability scanning of images when they are pushed to the repository."
}

variable "encryption_type" {
  type        = string
  default     = "AES256"
  description = "Encryption type for the repository. Allowed values: AES256 or KMS."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "ARN of the KMS key to use for encryption (required if encryption_type is KMS)."
}

variable "force_delete" {
  type        = bool
  default     = false
  description = "If true, delete the repository even if it contains images (useful for dev/test environments)."
}

