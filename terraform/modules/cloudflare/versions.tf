# -----------------------------------------------------------------------------
# Terraform Requirements
#
# Purpose:
# Declares the providers required by the Cloudflare module.
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}