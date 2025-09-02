variable "name"            { type = string }  
variable "image"           { type = string }  
variable "cpu"             { 
    type = number  
    default = 512 
}    
variable "memory"          { 
    type = number  
    default = 1024 
}   
variable "subnet_ids"      { type = list(string) }              
variable "security_group"  { type = string }                    
variable "env"             { 
    type = map(string) 
    default = {}
}  
variable "tags"            { 
    type = map(string) 
    default = {} 
}
