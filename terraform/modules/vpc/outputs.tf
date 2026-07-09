output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "vpc_project" {
  value = aws_vpc.main.tags["Project"]
}

output "private_subnets" {
  value = aws_subnet.private.*.id
}

output "public_subnets" {
  value = aws_subnet.public.*.id
}