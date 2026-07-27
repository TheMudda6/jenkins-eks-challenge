#
# Provider & Terraform Version Requirements
#
# Purpose:
# Defines the Terraform version and provider
# versions this module has been developed and
# tested against. This makes the module
# portable and self-contained.
#

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

