resource "aws_sqs_queue" "orders" {

  name = "${var.project_name}-${var.environment}-orders"

  visibility_timeout_seconds = 30

  message_retention_seconds = 345600

  receive_wait_time_seconds = 20

  tags = {
    Name        = "${var.project_name}-${var.environment}-orders"
    Environment = var.environment
    Project     = var.project_name
  }
}