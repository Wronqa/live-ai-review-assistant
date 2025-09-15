output "queue_url" { value = aws_sqs_queue.review.url }
output "queue_arn" { value = aws_sqs_queue.review.arn }
output "dlq_url"   { value = aws_sqs_queue.dlq.url }
