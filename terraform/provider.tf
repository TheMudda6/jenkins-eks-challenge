# -----------------------------------------------------------------------------
# Terraform Providers
#
# Purpose:
# Configures the Terraform providers required to manage AWS, Kubernetes/Helm
# and Cloudflare resources used by the Jenkins EKS platform.
#
# Kubernetes access is configured through the EKS cluster endpoint and AWS
# authentication so Terraform can manage Helm releases after the cluster exists.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.22"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name
      ]
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}