resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  fifo_queue                = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  message_retention_seconds   = var.dlq_message_retention_seconds
  visibility_timeout_seconds  = var.dlq_visibility_timeout_seconds
  delay_seconds               = 0
  receive_wait_time_seconds   = 0
  max_message_size            = var.max_message_size

  tags = merge(local.tags, { Name = "${local.name}-dlq", Component = "sqs-dlq" })
}

resource "aws_sqs_queue" "main" {
  name                       = local.name

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null


  visibility_timeout_seconds  = var.visibility_timeout_seconds
  message_retention_seconds   = var.message_retention_seconds
  delay_seconds               = var.delay_seconds
  receive_wait_time_seconds   = var.receive_wait_time_seconds
  max_message_size            = var.max_message_size


  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(local.tags, { Name = "${local.name}-queue", Component = "sqs-main" })
}


