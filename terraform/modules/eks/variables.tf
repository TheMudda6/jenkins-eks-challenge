# -----------------------------------------------------------------------------
# Cluster Configuration
#
# Purpose:
# Defines the core configuration of the EKS control plane.
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The version of the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "tags" {
  description = "A map of tags to assign to the EKS cluster."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Networking
#
# Purpose:
# Defines where the EKS cluster and worker nodes are deployed.
# -----------------------------------------------------------------------------

variable "subnet_ids" {
  description = "A list of subnet IDs where the EKS cluster will be deployed."
  type        = list(string)
}

# -----------------------------------------------------------------------------
# IAM Roles
#
# Purpose:
# Defines the IAM roles used by the EKS cluster, worker nodes and add-ons.
# -----------------------------------------------------------------------------

variable "cluster_role_arn" {
  description = "The ARN of the IAM role that EKS will use to manage the cluster."
  type        = string
}

variable "node_role_arn" {
  description = "The ARN of the IAM role that EKS worker nodes will use."
  type        = string
}

# -----------------------------------------------------------------------------
# Managed Node Group
#
# Purpose:
# Defines the scaling and EC2 configuration for worker nodes.
# -----------------------------------------------------------------------------

variable "desired_size" {
  description = "The desired number of worker nodes in the EKS node group."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "The minimum number of worker nodes in the EKS node group."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "The maximum number of worker nodes in the EKS node group."
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "The EC2 instance type for the EKS worker nodes."
  type        = string
  default     = "t3.small"
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM Role ARN used by the Amazon EBS CSI Driver add-on."
  type        = string
}