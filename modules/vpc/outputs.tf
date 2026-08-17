output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

# Iterating local.azs rather than the resource map keeps these lists in AZ
# order. A splat does not work on a for_each map, and values() would sort
# lexically rather than by the order the AZs were selected.
output "public_subnet_ids" {
  description = "IDs of the public subnets, one per availability zone."
  value       = [for az in local.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets, one per availability zone."
  value       = [for az in local.azs : aws_subnet.private[az].id]
}

output "availability_zones" {
  description = "Availability zones the subnets span."
  value       = local.azs
}
