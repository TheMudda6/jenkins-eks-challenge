# -----------------------------------------------------------------------------
# Private Subnet IDs
#
# Purpose:
# Exposes the IDs of all private subnets for other modules,
# such as the EKS module.
# -----------------------------------------------------------------------------

output "private_subnets" {
  description = "IDs of the private subnets."
  value       = values(aws_subnet.private)[*].id
}

# -----------------------------------------------------------------------------
# Public Subnet IDs
#
# Purpose:
# Exposes the IDs of all public subnets.
# -----------------------------------------------------------------------------

output "public_subnets" {
  description = "IDs of the public subnets."
  value       = values(aws_subnet.public)[*].id
}

# -----------------------------------------------------------------------------
# VPC ID
#
# Purpose:
# Exposes the VPC ID so other modules can deploy resources into it.
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}