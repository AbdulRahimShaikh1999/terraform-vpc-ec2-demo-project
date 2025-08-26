provider "aws" {
  region = "us-east-1"
}



locals {
  common_tags = {
    Project   = "vpc-ec2-nginx"
    Owner     = "you"
    ManagedBy = "Terraform"
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



# --- Security Group: allow HTTP/HTTPS in, all out
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP/HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "web-sg" })
}

# --- AMI lookup: Ubuntu 22.04 LTS (Canonical) in your region
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- EC2 (Ubuntu) in the PUBLIC subnet
resource "aws_instance" "web_ubuntu" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true  # subnet also auto-assigns

  tags = merge(local.common_tags, { Name = "web-ubuntu" })
}
