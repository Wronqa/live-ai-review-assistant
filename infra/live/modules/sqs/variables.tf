variable "name" { type = string } 
variable "visibility_timeout_seconds" {          
  type    = number
  default = 900                                 
}
variable "max_receive_count" {             
  type    = number
  default = 5
}
variable "tags" { 
  type = map(string) 
  default = {}
}