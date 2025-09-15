variable "name" { type = string } 
variable "visibility_timeout_seconds" {          
  type    = number
  default = 900                                 
}

variable "tags" { 
  type = map(string) 
  default = {}
}

variable "fifo_queue" {
  type        = bool
  default     = false
  description = "Create FIFO queue (adds .fifo if missing, enables FIFO features)."
}

variable "content_based_deduplication" {
  type        = bool
  default     = false
  description = "Enable content-based deduplication (FIFO only)."
}

variable "message_retention_seconds" {
  type        = number
  default     = 345600 
  description = "How long to retain messages (60..1209600)."
}

variable "delay_seconds" {
  type        = number
  default     = 0
  description = "Delivery delay for messages (0..900)."
}

variable "receive_wait_time_seconds" {
  type        = number
  default     = 10
  description = "Long polling wait time (0..20)."
}

variable "max_message_size" {
  type        = number
  default     = 262144 
  description = "Max message size in bytes."
}

variable "dlq_message_retention_seconds" {
  type        = number
  default     = 1209600 
  description = "Retention for the DLQ."
}

variable "dlq_visibility_timeout_seconds" {
  type        = number
  default     = 30
  description = "Visibility timeout for the DLQ."
}

variable "max_receive_count" {
  type        = number
  default     = 5
  description = "Number of times a message is received before moving to DLQ."
}
