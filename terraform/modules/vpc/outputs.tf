# -----------------------------------------------------------------------------
# Private Subnet IDs
#
# Purpose:
# Exposes the IDs of all private subnets for other modules,
# such as the EKS module.
# -----------------------------------------------------------------------------

output "private_subnets" {
  description = "Private subnet IDs used by other Terraform modules."
  value       = values(aws_subnet.private)[*].id
}

# -----------------------------------------------------------------------------
# Public Subnet IDs
#
# Purpose:
# Exposes the IDs of all public subnets.
# -----------------------------------------------------------------------------

output "public_subnets" {
  description = "Public subnet IDs used by internet-facing resources."
  value       = values(aws_subnet.public)[*].id
}

# -----------------------------------------------------------------------------
# VPC ID
#
# Purpose:
# Exposes the VPC ID so other modules can deploy resources into it.
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID used by dependent Terraform modules."
  value       = aws_vpc.main.id
}