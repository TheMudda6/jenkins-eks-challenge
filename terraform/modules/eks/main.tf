# -----------------------------------------------------------------------------
# Amazon EKS Cluster
#
# Purpose:
# Creates the Amazon Elastic Kubernetes Service (EKS) control plane.
#
# The control plane manages the Kubernetes API server and cluster state,
# while worker nodes run the application workloads.
# -----------------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"

  }

  # Defines which subnets the EKS control plane and managed networking
  # components use for cluster communication.

  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

resource "aws_eks_access_entry" "github_actions_terraform" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.github_actions_terraform_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_terraform" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.github_actions_terraform_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# -----------------------------------------------------------------------------
#
# Karpenter Security Group Discovery Tag
#
# Purpose:
# Tags the EKS-managed cluster security group so Karpenter can discover
# the security group when provisioning EC2 worker nodes.
#
# -----------------------------------------------------------------------------

resource "aws_ec2_tag" "karpenter_cluster_security_group" {
  resource_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id

  key   = "karpenter.sh/discovery"
  value = aws_eks_cluster.main.name
}

# -----------------------------------------------------------------------------
# Amazon EBS CSI Driver Add-on
#
# Purpose:
# Installs the Amazon EBS CSI Driver into the EKS cluster.
#
# This add-on enables Kubernetes Persistent Volumes backed by
# Amazon Elastic Block Store (EBS).
# -----------------------------------------------------------------------------

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_driver_role_arn

  # Ensure Terraform replaces any existing EBS CSI Driver configuration
  # so the cluster matches the desired state defined in code.

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# -----------------------------------------------------------------------------
# Amazon VPC CNI Add-on
#
# Purpose:
# Installs the Amazon VPC CNI as an EKS-managed add-on.
#
# NetworkPolicy enforcement is enabled so Kubernetes NetworkPolicy resources
# are enforced by the AWS VPC CNI networking layer.
# -----------------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}
