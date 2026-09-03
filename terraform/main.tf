# -----------------------------------------------------------------------------
# VPC Module
#
# Purpose:
# Creates the networking foundation for the platform, including the VPC,
# subnets, Internet Gateway, NAT Gateway and route tables.
# -----------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  # ---------------------------------------------------------------------------
  # VPC Configuration
  # ---------------------------------------------------------------------------

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets


  # ---------------------------------------------------------------------------
  # Project Configuration
  # ---------------------------------------------------------------------------

  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner

  cluster_name = var.cluster_name

}

# -----------------------------------------------------------------------------
# IAM Module
#
# Purpose:
# Creates the IAM Roles and Policies required by the EKS platform,
# including roles for the EKS control plane, worker nodes and Kubernetes
# controllers using IAM Roles for Service Accounts (IRSA).
# -----------------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  # ---------------------------------------------------------------------------
  # IAM Role & Policy Names
  #
  # Purpose:
  # Defines the names of the IAM Roles and Policies created for the
  # EKS platform.
  # ---------------------------------------------------------------------------

  eks_cluster_role_name                    = var.eks_cluster_role_name
  node_group_role_name                     = var.node_group_role_name
  ebs_csi_driver_role_name                 = var.ebs_csi_driver_role_name
  aws_load_balancer_controller_role_name   = var.aws_load_balancer_controller_role_name
  aws_load_balancer_controller_policy_name = var.aws_load_balancer_controller_policy_name
  event_producer_role_name                 = var.event_producer_role_name
  event_worker_role_name                   = var.event_worker_role_name
  event_producer_policy_name               = var.event_producer_policy_name
  event_worker_policy_name                 = var.event_worker_policy_name

  github_actions_oidc_role_name = var.github_actions_oidc_role_name

  ecr_repository_arns = toset(values(module.ecr.repository_arns))

  application_namespace = "jenkins"

  orders_queue_arn = module.sqs.queue_arn

  postgres_secret_arn = module.secrets.postgres_secret_arn

  # ---------------------------------------------------------------------------
  # Route 53 / ExternalDNS / cert-manager
  # ---------------------------------------------------------------------------

  route53_zone_id          = var.route53_zone_id
  external_dns_role_name   = var.external_dns_role_name
  external_dns_policy_name = var.external_dns_policy_name
  cert_manager_role_name   = var.cert_manager_role_name
  cert_manager_policy_name = var.cert_manager_policy_name

  oidc_provider_arn = module.eks.oidc_provider_arn

  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url

}

# -----------------------------------------------------------------------------
# EKS Module
#
# Purpose:
# Creates the Kubernetes control plane and managed node group.
#
# Consumes:
# - Private subnet IDs from the VPC module
# - Cluster role ARN from the IAM module
# - Node group role ARN from the IAM module
# -----------------------------------------------------------------------------

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  subnet_ids = module.vpc.private_subnets

  cluster_role_arn = module.iam.eks_cluster_role_arn
  node_role_arn    = module.iam.node_group_role_arn

  min_size     = var.min_size
  desired_size = var.desired_size
  max_size     = var.max_size

  instance_type = var.instance_type

  tags = var.tags

  ebs_csi_driver_role_arn = module.iam.ebs_csi_driver_role_arn
}

# -----------------------------------------------------------------------------
# ArgoCD Module
#
# Purpose:
# Installs ArgoCD into the Kubernetes cluster using Helm.
# ArgoCD will later become responsible for deploying the application
# from the Git repository (GitOps).
# -----------------------------------------------------------------------------

module "argocd" {
  source = "./modules/argocd"

  namespace     = "argocd"
  chart_version = var.argocd_chart_version
}

# -----------------------------------------------------------------------------
# SQS Module
#
# Purpose:
# Creates the Amazon SQS queues used for asynchronous communication between
# application services.
#
# Outputs have been defined in the SQS module to expose the queue URL, ARN and name for
# consumption by other modules or resources.
# -----------------------------------------------------------------------------

module "sqs" {
  source = "./modules/sqs"

  project_name = var.project_name
  environment  = var.environment

}

output "queue_url" {
  description = "Orders queue URL"
  value       = module.sqs.queue_url
}

output "queue_arn" {
  description = "Orders queue ARN"
  value       = module.sqs.queue_arn
}

output "queue_name" {
  description = "Orders queue name"
  value       = module.sqs.queue_name
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

output "repository_urls" {
  description = "ECR repository URLs keyed by service name."
  value       = module.ecr.repository_urls
}

output "repository_names" {
  description = "ECR repository names keyed by service name."
  value       = module.ecr.repository_names
}

output "github_actions_role_arn" {
  description = "GitHub Actions IAM Role ARN"
  value       = module.iam.github_actions_role_arn
}

module "secrets" {
  source = "./modules/secrets"

  postgres_password = var.postgres_password
}

# -----------------------------------------------------------------------------
#
# Karpenter Module
#
# Purpose:
# Installs Karpenter and creates the IAM resources required for dynamic
# Kubernetes worker-node provisioning.
#
# -----------------------------------------------------------------------------

module "karpenter" {
  source = "./modules/karpenter"

  cluster_name = var.cluster_name

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url

  namespace     = "kube-system"
  chart_version = var.karpenter_chart_version
}