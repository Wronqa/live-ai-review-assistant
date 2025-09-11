variable "name"             { type = string }                        
variable "source_queue_arn" { type = string }                        
variable "cluster_arn"      { type = string }                        
variable "task_definition_arn" { type = string }                     
variable "subnet_ids"       { type = list(string) }                  
variable "security_group_ids" { type = list(string) }                
variable "assign_public_ip" { 
    type = bool   
    default = true 
}         
variable "batch_size"       { 
    type = number 
    default = 1 
}            
variable "container_name"   { 
    type = string 
    default = "ecs-reviewer" 
} 
variable "event_env_name"   { 
    type = string 
    default = "EVENT" 
}        
variable "execution_role_arn"{
    type = string
}

variable "task_role_arn"{
    type = string
}

variable "enrichment_lambda_arn" {
  type        = string
  default     = ""
  description = "If set, Pipe will call this Lambda to enrich events (InputTemplate <$.body>)."
}