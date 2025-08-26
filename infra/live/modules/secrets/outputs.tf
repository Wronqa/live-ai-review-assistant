output "names" {
  value = [for k, _ in aws_secretsmanager_secret.this : k]
}
output "arns" {
  value = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}