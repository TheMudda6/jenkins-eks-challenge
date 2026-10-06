# -----------------------------------------------------------------------------
# AWS Region
#
# Purpose:
# Provides the current AWS region for regional resources and service policies.
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Common Resource Tags
#
# Purpose:
# Defines tags shared by all AWS resources created within this module.
# -----------------------------------------------------------------------------

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# -----------------------------------------------------------------------------
# Virtual Private Cloud (VPC)
#
# Purpose:
# Creates the private network that contains all infrastructure for the project.
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = var.vpc_name
  })
}

# -----------------------------------------------------------------------------
# Default VPC Security Group
#
# Purpose:
# Removes the default inbound and outbound rules from the VPC's default
# security group so that resources cannot unintentionally inherit permissive
# network access.
#
# Application and Kubernetes traffic must use explicitly defined security
# groups instead.
# -----------------------------------------------------------------------------

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-default-sg"
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs KMS Key
#
# Purpose:
# Creates the customer-managed KMS key used to encrypt the CloudWatch Log
# Group that stores VPC Flow Logs.
#
# AWS Requirement:
# CloudWatch Logs KMS keys must be created in the same AWS region as the
# log group. This module uses the project's default AWS provider region.
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "vpc_flow_logs" {
  description             = "VPC Flow Logs CloudWatch encryption key for ${var.vpc_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/${var.vpc_name}/flow-logs"
          }
        }
      },
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-vpc-flow-logs-kms"
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs CloudWatch Log Group
#
# Purpose:
# Stores VPC Flow Log records in CloudWatch Logs for network visibility,
# troubleshooting, and security auditing.
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.vpc_name}/flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpc_flow_logs.arn

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-vpc-flow-logs"
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs IAM Role
#
# Purpose:
# Allows the VPC Flow Logs service to publish flow-log records to the
# CloudWatch Log Group created above.
# -----------------------------------------------------------------------------

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.vpc_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.vpc_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# VPC Flow Logs
#
# Purpose:
# Captures all accepted and rejected network traffic for the VPC and delivers
# the records to the dedicated CloudWatch Log Group.
# -----------------------------------------------------------------------------

resource "aws_flow_log" "main" {
  iam_role_arn         = aws_iam_role.vpc_flow_logs.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  traffic_type = "ALL"
  vpc_id       = aws_vpc.main.id

  max_aggregation_interval = 60

  depends_on = [
    aws_iam_role_policy.vpc_flow_logs
  ]
}

# -----------------------------------------------------------------------------
# Private Subnets
#
# Purpose:
# Creates the private subnets that host Kubernetes worker nodes and application
# workloads. These subnets are not directly accessible from the internet.
# -----------------------------------------------------------------------------

resource "aws_subnet" "private" {

  for_each = toset(var.private_subnets)

  vpc_id = aws_vpc.main.id

  cidr_block = each.value

  availability_zone = element(var.availability_zones, index(var.private_subnets, each.value))

  tags = merge(local.common_tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })

}

# TODO:
# Refactor subnet configuration to use a map/object instead of relying on
# matching indexes between two separate lists.
#
# Example:
#
# private_subnets = {
#   eu-west-2a = "10.0.1.0/24"
#   eu-west-2b = "10.0.2.0/24"
# }
#
# This removes the dependency on list ordering, improves readability,
# and makes Availability Zone assignments explicit.

# -----------------------------------------------------------------------------
# Public Subnets
#
# Purpose:
# Creates the public subnets that host internet-facing infrastructure such as
# the NAT Gateway and Application Load Balancer.
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets)

  vpc_id = aws_vpc.main.id

  cidr_block = each.value

  availability_zone = element(var.availability_zones, index(var.public_subnets, each.value))
}

# -----------------------------------------------------------------------------
# Internet Gateway
#
# Purpose:
# Provides internet connectivity for resources deployed within public subnets.
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Route Table
#
# Purpose:
# Routes outbound internet traffic from public subnets through the Internet
# Gateway.
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-public-rt"
  })

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# -----------------------------------------------------------------------------
# Private Route Table
#
# Purpose:
# Routes outbound internet traffic from private subnets through the NAT Gateway
# while preventing direct inbound internet access.
# -----------------------------------------------------------------------------

resource "aws_route_table" "private" {

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-private-rt"
  })

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

# -----------------------------------------------------------------------------
# Public Route Table Associations
#
# Purpose:
# Associates each public subnet with the public route table.
# -----------------------------------------------------------------------------

resource "aws_route_table_association" "public" {

  for_each = toset(var.public_subnets)

  subnet_id      = aws_subnet.public[each.value].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Private Route Table Associations
#
# Purpose:
# Associates each private subnet with the private route table.
# -----------------------------------------------------------------------------

resource "aws_route_table_association" "private" {

  for_each = toset(var.private_subnets)

  subnet_id      = aws_subnet.private[each.value].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Elastic IP
#
# Purpose:
# Allocates a static public IP address for the NAT Gateway.
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-nat-eip"
  })
}

# -----------------------------------------------------------------------------
# NAT Gateway
#
# Purpose:
# Provides outbound internet access for resources in private subnets.
#
# Design Decision:
# A single NAT Gateway is used to reduce AWS costs for this portfolio project.
# In a production environment, a NAT Gateway would typically be deployed in
# each Availability Zone for higher availability.
# -----------------------------------------------------------------------------

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  subnet_id = values(aws_subnet.public)[0].id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-nat-gateway"
  })
}