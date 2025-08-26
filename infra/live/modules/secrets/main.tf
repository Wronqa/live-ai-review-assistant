resource "aws_secretsmanager_secret" "this" {
  for_each = toset(var.names)

  name = each.value
  tags = var.tags

  recovery_window_in_days = 7
}

