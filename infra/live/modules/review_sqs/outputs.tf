output "queue_url" {
  description = "URL of the review SQS queue."
  value       = aws_sqs_queue.review.url
}

output "queue_arn" {
  description = "ARN of the review SQS queue."
  value       = aws_sqs_queue.review.arn
}

output "dlq_url" {
  description = "URL of the dead-letter queue (DLQ) for the review SQS queue."
  value       = aws_sqs_queue.dlq.url
}


output "dlq_arn" {
  description = "URL of the dead-letter queue (DLQ) for the review SQS queue."
  value       = aws_sqs_queue.dlq.arn
}
