locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
  Name = var.vpc_name
})
  }

resource "aws_subnet" "private" {

  for_each = toset(var.private_subnets)

  vpc_id = aws_vpc.main.id

  cidr_block = each.value

  availability_zone = element(var.availability_zones, index(var.private_subnets, each.value))

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

resource "aws_subnet" "public" {
  for_each = toset(var.public_subnets)

  vpc_id = aws_vpc.main.id

  cidr_block = each.value

  availability_zone = element(var.availability_zones, index(var.public_subnets, each.value))
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-igw"
  })
}

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

resource "aws_route_table_association" "public" {

  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {

  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

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



  