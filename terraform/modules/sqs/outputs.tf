# -----------------------------------------------------------------------------
#
# SQS Module Outputs
#
# Purpose:
# Exposes the orders queue URL, ARN and name for use by other
# Terraform modules and application configuration.
#
# -----------------------------------------------------------------------------

output "queue_url" {
  description = "URL of the orders queue"
  value       = aws_sqs_queue.orders.url
}

output "queue_arn" {
  description = "ARN of the orders queue"
  value       = aws_sqs_queue.orders.arn
}

output "queue_name" {
  description = "Name of the orders queue"
  value       = aws_sqs_queue.orders.name
}