variable "name" {
  type        = string
  description = "Base name for the SQS queue (DLQ name will be derived from this)."
}

variable "visibility_timeout_seconds" {
  type        = number
  default     = 900
  description = "Visibility timeout for the main queue (in seconds). Defines how long a message remains invisible after being received."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to both the main SQS queue and its DLQ."
}

variable "fifo_queue" {
  type        = bool
  default     = false
  description = "Whether to create a FIFO queue. If true, enforces the .fifo suffix and enables FIFO features."
}

variable "content_based_deduplication" {
  type        = bool
  default     = false
  description = "Enable content-based deduplication for FIFO queues (deduplicates messages with the same content within 5 minutes)."
}

variable "message_retention_seconds" {
  type        = number
  default     = 345600
  description = "How long messages are retained in the main queue (between 60 seconds and 14 days)."
}

variable "delay_seconds" {
  type        = number
  default     = 0
  description = "Delivery delay for all messages (0–900 seconds)."
}

variable "receive_wait_time_seconds" {
  type        = number
  default     = 10
  description = "Long polling wait time (0–20 seconds). Reduces empty responses and cost."
}

variable "max_message_size" {
  type        = number
  default     = 262144
  description = "Maximum message size in bytes (1024–262144)."
}

variable "dlq_message_retention_seconds" {
  type        = number
  default     = 1209600
  description = "How long messages are retained in the dead-letter queue (between 60 seconds and 14 days)."
}

variable "dlq_visibility_timeout_seconds" {
  type        = number
  default     = 30
  description = "Visibility timeout for the dead-letter queue (in seconds)."
}

variable "max_receive_count" {
  type        = number
  default     = 5
  description = "Number of times a message can be received before being moved to the dead-letter queue."
}
