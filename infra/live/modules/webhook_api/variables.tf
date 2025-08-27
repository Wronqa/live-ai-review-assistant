variable "name"              { type = string }    
variable "env"               { type = string }   
variable "lambda_source_dir" { type = string }   
variable "memory_size"       { 
    type = number  
    default = 256 
}
variable "timeout"           { 
    type = number  
    default = 10 
}
variable "tags"              { 
    type = map(string) 
    default = {} 
}

variable "webhook_secret_id" { type = string }       
variable "github_token_id"   { type = string }      
variable "sqs_queue_arn"     { type = string }     
variable "sqs_queue_url"     { type = string }       
