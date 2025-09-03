resource "aws_iam_policy" "secrets_read" {
  name   = "${var.name}-secrets-read"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = var.secret_arns
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = var.role_name   
  policy_arn = aws_iam_policy.secrets_read.arn
}
