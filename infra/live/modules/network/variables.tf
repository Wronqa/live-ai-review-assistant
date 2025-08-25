variable "name"      { type = string }
variable "vpc_cidr"  { 
    type = string  
    default = "10.42.0.0/16" 
}
variable "azs"       { 
    type = list(string) 
    default = ["eu-north-1a", "eu-north-1b", "eu-north-1c"] 
}
variable "tags"      { 
    type = map(string) 
    default = {} 
}