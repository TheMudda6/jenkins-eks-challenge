# VPC Module

# -----------------------------------------------------------------------------
# VPC Module
# Purpose:
# Creates the networking foundation for the platform, including the VPC,
# subnets, Internet Gateway, NAT Gateway and route tables.
# -----------------------------------------------------------------------------

module "vpc" {
  source = "./modules/vpc"

  # Inputs from variables.tf go here

  vpc_name           = var.vpc_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets

  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner
}

# IAM Module
#
# Purpose:
# Creates the IAM roles and policies required for the EKS cluster and managed node group.

module "iam" {
  source = "./modules/iam"

  # Inputs from variables.tf go here

  eks_cluster_role_name = var.eks_cluster_role_name
  node_group_role_name  = var.node_group_role_name
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
}
