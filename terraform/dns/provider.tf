# -----------------------------------------------------------------------------
#
# Terraform DNS Providers
#
# Purpose:
# Configures the AWS provider used to manage the dedicated Jenkins Route 53
# hosted zone.
#
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
