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

variable "subnet_ids" {
  description = "A list of subnet IDs where the EKS cluster will be deployed."
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "The ARN of the IAM role that EKS will use to manage the cluster."
  type        = string
}

variable "node_role_arn" {
  description = "The ARN of the IAM role that EKS worker nodes will use."
  type        = string
}

variable "desired_size" {
  description = "The desired number of worker nodes in the EKS node group."
  type        = number
  default     = 1
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