variable "name" {
  description = "Unique managed policy name."
  type        = string
}

variable "secret_arns" {
  description = "List of Secrets Manager ARNs allowed to read."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the managed policy."
  type        = map(string)
  default     = {}
}
