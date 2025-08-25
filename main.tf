provider "aws" {
  region = "us-east-1"
}

locals {
  common_tags = {
    Project = "vpc-ec2-nginx", Owner   = "you"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "main-vpc" })
}


################
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.16.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "public-a"
    Tier = "public"
  })
}

# Private subnet
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.16.2.0/24"
  availability_zone = "us-east-1b"

  tags = merge(local.common_tags, {
    Name = "private-b"
    Tier = "private"
  })
}



######################

# --- Internet Gateway (attach to the VPC)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "main-igw" })
}

# --- Public Route Table (default route to the IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "rtb-public" })
}

# Route: all IPv4 traffic -> IGW
resource "aws_route" "public_inet_v4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# (Optional) IPv6 default route if your VPC has IPv6
# resource "aws_route" "public_inet_v6" {
#   route_table_id              = aws_route_table.public.id
#   destination_ipv6_cidr_block = "::/0"
#   gateway_id                  = aws_internet_gateway.igw.id
# }

# --- Associate public route table with the PUBLIC subnet
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}


#######################



