
locals {
  name                 = var.name
  cluster_name         = "${local.name}-cluster"
  task_family          = "${local.name}-td"
  log_group_name       = coalesce(var.log_group_name, "/ecs/${local.name}")
  tags                 = merge(var.tags, { ManagedBy = "terraform" })
  task_role_name       = coalesce(var.task_role_name, "${local.name}-task-role")
  task_s3_policy_name  = coalesce(var.task_s3_policy_name, "${local.name}-task-s3-policy")
}