variable "name"                    { type = string }
variable "lambda_src_dir"          { type = string }   
variable "queue_arn"               { type = string }
variable "queue_url"               { type = string }
variable "cluster_arn"             { type = string }
variable "task_def_arn"            { type = string }
variable "subnet_ids"              { type = list(string) }
variable "security_group"          { type = string }
variable "task_role_arn"           { type = string }  
variable "execution_role_arn"      { type = string }   
variable "tags"                    { 
    type = map(string) 
    default = {} 
}
