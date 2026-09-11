# -----------------------------------------------------------------------------
#
# Terraform Providers
#
# Purpose:
# Configures the Terraform providers required to manage AWS, Kubernetes/Helm
# and Cloudflare resources used by the Jenkins EKS platform.
#
# Kubernetes access is configured through the EKS cluster endpoint and AWS
# authentication so Terraform can manage Kubernetes resources after the
# cluster exists.
#
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

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "helm" {
  kubernetes {
    host = var.terraform_bootstrap ? "https://127.0.0.1:65535" : var.kubernetes_host

    cluster_ca_certificate = var.terraform_bootstrap ? null : base64decode(var.kubernetes_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.terraform_bootstrap ? "bootstrap-placeholder" : var.kubernetes_cluster_name
      ]
    }
  }
}

provider "kubernetes" {
  host                   = var.terraform_bootstrap ? "https://127.0.0.1:65535" : var.kubernetes_host
  cluster_ca_certificate = var.terraform_bootstrap ? null : base64decode(var.kubernetes_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.terraform_bootstrap ? "bootstrap-placeholder" : var.kubernetes_cluster_name
    ]
  }
}