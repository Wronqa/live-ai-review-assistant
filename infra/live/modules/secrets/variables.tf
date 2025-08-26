variable "names" {
  description = "List with secrets name"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}