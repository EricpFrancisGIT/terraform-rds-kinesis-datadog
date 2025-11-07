data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

# Two private subnets for DB
resource "aws_subnet" "private" {
  for_each                = { for i, az in slice(data.aws_availability_zones.available.names, 0, var.az_count) : i => az }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, tonumber(each.key) + 8) # carve from higher space
  availability_zone       = each.value
  map_public_ip_on_launch = false
  tags                    = merge(local.common_tags, { Name = "${local.name}-pri-${each.value}" })
}

# One public subnet + IGW + route (for NAT, Lambda egress if you later add NAT)
resource "aws_subnet" "public" {
  for_each                = { for i, az in slice(data.aws_availability_zones.available.names, 0, var.az_count) : i => az }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, tonumber(each.key))
  availability_zone       = each.value
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${local.name}-pub-${each.value}" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.name}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route_table_association" "pub_assoc" {
  for_each       = aws_subnet.public
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}
