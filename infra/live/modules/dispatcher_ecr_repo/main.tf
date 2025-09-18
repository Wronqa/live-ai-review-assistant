resource "aws_ecr_repository" "this" {
  name                 = local.name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
     scan_on_push = var.scan_on_push 
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  force_delete = var.force_delete

  tags = merge(local.tags, { Name = "${var.name}-ecr",  Component = "ecr" })
}

resource "aws_ecr_lifecycle_policy" "keep_last_10" {
  repository = aws_ecr_repository.this.name
  policy     = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last 10 images",
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 },
      action       = { type = "expire" }
    }]
  })
}