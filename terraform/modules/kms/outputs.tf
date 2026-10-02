# -----------------------------------------------------------------------------
#
# AWS KMS Module Outputs
#
# Purpose:
# Exposes customer-managed KMS key identifiers to Terraform modules that
# require encryption.
#
# -----------------------------------------------------------------------------

output "secrets_key_arn" {
  description = "ARN of the customer-managed KMS key used for Secrets Manager."
  value       = aws_kms_key.secrets.arn
}

output "secrets_key_id" {
  description = "ID of the customer-managed KMS key used for Secrets Manager."
  value       = aws_kms_key.secrets.key_id
}

output "sqs_key_arn" {
  description = "ARN of the customer-managed KMS key used for SQS."
  value       = aws_kms_key.sqs.arn
}

output "ecr_key_arn" {
  description = "ARN of the customer-managed KMS key used for ECR."
  value       = aws_kms_key.ecr.arn
}