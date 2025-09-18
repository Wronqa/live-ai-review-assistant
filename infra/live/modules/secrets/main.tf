resource "aws_secretsmanager_secret" "this" {
  for_each = toset(local.names)

  name = each.value
  tags = merge(local.tags, { Name = "${local.name}-${each.value}", Component = "secret" })

  recovery_window_in_days = 7
}

