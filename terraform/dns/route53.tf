# -----------------------------------------------------------------------------
#
# Route 53 Jenkins DNS
#
# Purpose:
# Creates a dedicated public Route 53 hosted zone for the Jenkins subdomain.
#
# Cloudflare remains authoritative for mud-as-sir.uk. The Jenkins subdomain
# will be delegated from Cloudflare to this Route 53 hosted zone so that
# ExternalDNS and cert-manager can manage Jenkins DNS records independently.
#
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "jenkins" {
  name = var.jenkins_zone_name

  tags = {
    Name        = "jenkins-${var.environment}-dns"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Route 53 DNSSEC KMS Key
#
# Purpose:
# Creates the asymmetric customer-managed KMS key required by Route 53
# DNSSEC signing for the Jenkins hosted zone.
#
# AWS Requirement:
# Route 53 DNSSEC requires an asymmetric ECC_NIST_P256 signing key in
# us-east-1 with SIGN_VERIFY key usage.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "route53_dnssec" {
  provider = aws.us-east-1

  description              = "Route 53 DNSSEC signing key for ${var.jenkins_zone_name}"
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRoute53DNSSEC"
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:Verify"
        ]
        Resource = "*"
      },
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "route53-${var.environment}-dnssec"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Route 53 Key Signing Key
#
# Purpose:
# Associates the DNSSEC KMS signing key with the Jenkins hosted zone.
# -----------------------------------------------------------------------------

resource "aws_route53_key_signing_key" "jenkins" {
  hosted_zone_id             = aws_route53_zone.jenkins.zone_id
  key_management_service_arn = aws_kms_key.route53_dnssec.arn
  name                       = "jenkins-dnssec-ksk"
  status                     = "ACTIVE"
}

# -----------------------------------------------------------------------------
# Route 53 DNSSEC Signing
#
# Purpose:
# Enables DNSSEC signing for the Jenkins hosted zone using the active
# Route 53 Key Signing Key.
# -----------------------------------------------------------------------------

resource "aws_route53_hosted_zone_dnssec" "jenkins" {
  hosted_zone_id = aws_route53_zone.jenkins.zone_id

  depends_on = [
    aws_route53_key_signing_key.jenkins
  ]
}

# -----------------------------------------------------------------------------
# Route 53 Query Logging
#
# Purpose:
# Sends public DNS query logs for the Jenkins hosted zone to CloudWatch Logs.
#
# AWS Requirement:
# Route 53 query logging uses a CloudWatch Log Group and resource policy in
# us-east-1.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "route53_query_logs" {
  provider = aws.us-east-1

  name              = "/aws/route53/${var.jenkins_zone_name}"
  retention_in_days = 30

  tags = {
    Name        = "route53-${var.environment}-query-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_logs" {
  provider = aws.us-east-1

  policy_name = "route53-query-logging-${var.environment}"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRoute53QueryLogging"
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = aws_cloudwatch_log_group.route53_query_logs.arn
      }
    ]
  })
}

resource "aws_route53_query_log" "jenkins" {
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_logs.arn
  zone_id                  = aws_route53_zone.jenkins.zone_id

  depends_on = [
    aws_cloudwatch_log_resource_policy.route53_query_logs
  ]
}

output "jenkins_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the Jenkins subdomain."
  value       = aws_route53_zone.jenkins.zone_id
}

output "jenkins_name_servers" {
  description = "Route 53 name servers for the Jenkins subdomain delegation."
  value       = aws_route53_zone.jenkins.name_servers
}
