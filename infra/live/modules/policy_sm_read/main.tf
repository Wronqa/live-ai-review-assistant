data "aws_iam_policy_document" "this" {
  statement {
    sid     = "SecretsReadCurrentOnly"
    effect  = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = var.secret_arns


    condition {
      test     = "StringEqualsIfExists"
      variable = "secretsmanager:VersionStage"
      values   = ["AWSCURRENT"]
    }

    condition {
      test     = "Null"
      variable = "secretsmanager:VersionId"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "this" {
  name   = var.name
  policy = data.aws_iam_policy_document.this.json
  tags   = var.tags
}
