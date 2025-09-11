resource "aws_dynamodb_table" "this" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key = var.pk_attribute

  attribute {
    name = var.pk_attribute
    type = "S"
  }

  server_side_encryption {
    enabled     = var.sse_enabled
    kms_key_arn = var.sse_kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.pitr_enabled
  }

  dynamic "ttl" {
    for_each = var.ttl_enabled && var.ttl_attribute != null ? [1] : []
    content {
      attribute_name = var.ttl_attribute
      enabled        = true
    } 
  }

  tags = local.tags
}
