resource "aws_secretsmanager_secret" "this" {
  for_each = toset(var.names)

  name = each.value
  tags = merge(local.tags, { Name = "each.value", Component = "secret" })

  recovery_window_in_days = 7
}

