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
       
variable "execution_role_arn"{
    type = string
}

variable "task_role_arn"{
    type = string
}

