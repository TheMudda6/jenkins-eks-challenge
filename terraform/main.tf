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
}

# -----------------------------------------------------------------------------
# IAM Module
#
# Purpose:
# Creates the IAM Roles and Policies required by the EKS platform,
# including the control plane, worker nodes and supporting Kubernetes
# controllers.
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

  # ---------------------------------------------------------------------------
  # EKS OIDC Provider Information
  #
  # Purpose:
  # Passes the EKS OpenID Connect (OIDC) provider details into the IAM
  # module so IAM Roles for Service Accounts (IRSA) can be configured.
  # ---------------------------------------------------------------------------

  oidc_provider_arn       = module.eks.oidc_provider_arn
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

  # Existing configuration...

  ebs_csi_driver_role_arn = module.iam.ebs_csi_driver_role_arn
}

# -----------------------------------------------------------------------------
# Helm Module
#
# Purpose:
# Installs the AWS Load Balancer Controller using Helm.
#
# Consumes:
# - Cluster name from the EKS module
# - Namespace from the Helm module variables
# -----------------------------------------------------------------------------

module "helm" {
  source = "./modules/helm"

  namespace                             = var.kubernetes_namespace
  cluster_name                          = module.eks.cluster_name
  alb_ingress_controller_version        = var.alb_ingress_controller_version
  aws_load_balancer_controller_role_arn = module.iam.aws_load_balancer_controller_role_arn
}