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
