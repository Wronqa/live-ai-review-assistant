output "cluster_arn" {
  description = "ARN of the created ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition (latest revision)."
  value       = aws_ecs_task_definition.td.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role, used by the container to access AWS services."
  value       = aws_iam_role.task_role.arn
}

output "execution_role_arn" {
  description = "ARN of the ECS execution role, used by ECS to pull images and publish logs."
  value       = aws_iam_role.execution_role.arn
}

output "task_role_name" {
  description = "Name of the ECS task role (useful for attaching additional IAM policies externally)."
  value       = aws_iam_role.task_role.name
}

output "container_name" {
  description = "Name of the first container defined in the ECS task definition."
  value       = jsondecode(aws_ecs_task_definition.td.container_definitions)[0].name
}
