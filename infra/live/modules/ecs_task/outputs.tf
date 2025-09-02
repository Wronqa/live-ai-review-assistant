output "cluster_arn"         { value = aws_ecs_cluster.this.arn }
output "task_definition_arn" { value = aws_ecs_task_definition.td.arn }
output "task_role_arn"       { value = aws_iam_role.task_role.arn }
output "execution_role_arn"  { value = aws_iam_role.execution_role.arn }
output "subnet_ids"          { value = var.subnet_ids }
output "security_group"      { value = var.security_group }