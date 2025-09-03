variable "role_name"    { type = string }           
variable "secret_arns" { type = list(string) }     
variable "name"        { type = string }           
variable "tags"        { 
    type = map(string) 
    default = {} 
}
