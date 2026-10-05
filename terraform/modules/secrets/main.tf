# -----------------------------------------------------------------------------
#
# AWS Secrets Manager
#
# Purpose:
# Creates the AWS Secrets Manager secret used to securely store the
# PostgreSQL credentials required by the Jenkins platform.
#
# -----------------------------------------------------------------------------

# Checkov exception: CKV2_AWS_57
#
# Automatic Secrets Manager rotation is intentionally not enabled because
# this secret contains the PostgreSQL database credential. Rotation requires
# coordinated password changes in PostgreSQL and refresh/restart handling for
# workloads consuming the credential. That rotation workflow is not currently
# implemented in this project.
#

resource "aws_secretsmanager_secret" "postgres" {

  #checkov:skip=CKV2_AWS_57:PostgreSQL credential rotation requires coordinated database and workload rotation, which is not implemented.

  name = "jenkins/postgres"

  recovery_window_in_days = 0

  kms_key_id = var.kms_key_arn

  tags = {
    Name        = "postgres-secret"
    Project     = "jenkins-eks"
    Environment = "dev"
  }
}

resource "aws_secretsmanager_secret_version" "postgres" {

  secret_id = aws_secretsmanager_secret.postgres.id

  secret_string = jsonencode({
    POSTGRES_DB       = "orders"
    POSTGRES_USER     = "postgres"
    POSTGRES_PASSWORD = var.postgres_password
  })
}

# Checkov exception: CKV2_AWS_57
#
# Automatic Secrets Manager rotation is intentionally not enabled because
# Grafana consumes this credential directly. Rotation requires coordinated
# credential refresh handling for the Grafana workload, which is not
# currently implemented in this project.
#

resource "aws_secretsmanager_secret" "grafana" {

  #checkov:skip=CKV2_AWS_57:Grafana credential rotation requires coordinated workload refresh, which is not implemented.

  name                    = "jenkins/grafana"
  recovery_window_in_days = 0

  kms_key_id = var.kms_key_arn

  tags = {
    Name        = "grafana-secret"
    Project     = "jenkins-eks"
    Environment = "dev"
  }
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id

  secret_string = jsonencode({
    GF_SECURITY_ADMIN_USER     = "admin"
    GF_SECURITY_ADMIN_PASSWORD = var.grafana_password
  })
}
