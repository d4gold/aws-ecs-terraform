locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # AZ name -> position. Keying subnets by AZ name keeps their addresses
  # stable if AWS reorders the AZ list or az_count changes, while the position
  # still drives deterministic CIDR math.
  az_indexes = { for i, az in local.azs : az => i }

  tags = merge(var.tags, { Module = "vpc" })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = var.name })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}

# Public subnets: /24 carved from the VPC CIDR, one per AZ.
resource "aws_subnet" "public" {
  for_each = local.az_indexes

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, each.value)
  availability_zone       = each.key
  map_public_ip_on_launch = true
  tags                    = merge(local.tags, { Name = "${var.name}-public-${each.key}", Tier = "public" })
}

# Private subnets offset by 100 so the CIDR blocks never collide with public.
resource "aws_subnet" "private" {
  for_each = local.az_indexes

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, each.value + 100)
  availability_zone = each.key
  tags              = merge(local.tags, { Name = "${var.name}-private-${each.key}", Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# NAT gateway. THIS IS THE EXPENSIVE PART: ~$0.045/hr plus data processing.
# Default is OFF. Turn it on only when private-subnet egress is actually
# required.
# With NAT off, private subnets have no default route -- fine for RDS, and
# fine for Fargate tasks if you either run them in public subnets or add
# VPC endpoints for ECR/S3/CloudWatch Logs.
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.name}-nat" })
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[local.azs[0]].id
  tags          = merge(local.tags, { Name = "${var.name}-nat" })
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  for_each = local.az_indexes

  vpc_id = aws_vpc.main.id
  tags   = merge(local.tags, { Name = "${var.name}-private-${each.key}" })
}

# One default route per private route table, but only when the NAT exists.
# An empty map is the for_each equivalent of count = 0.
resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? local.az_indexes : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
