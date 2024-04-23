provider "aws" {
  region = "us-west-2"
}

# Data source for available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "eks_vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks_igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "public_subnet-${count.index}"
  }
}

# Elastic IPs for the NAT Gateways
resource "aws_eip" "nat_eip" {
  count  = length(data.aws_availability_zones.available.names)
  domain = "vpc"

  tags = {
    Name = "nat_eip-${count.index}"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_gw" {
  count         = length(data.aws_availability_zones.available.names)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  allocation_id = aws_eip.nat_eip[count.index].id

  tags = {
    Name = "nat_gw-${count.index}"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.${count.index + length(data.aws_availability_zones.available.names)}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private_subnet-${count.index}"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public_rta" {
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[0].id  # Предполагаем, что у вас один NAT Gateway
  }

  tags = {
    Name = "private_rt"
  }
}


# Private Route Table Associations
resource "aws_route_table_association" "private_rta" {
  count          = length(aws_subnet.private_subnet.*.id)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# EKS Cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-eks-cluster"
  cluster_version = "1.29"
  subnets         = aws_subnet.private_subnet.*.id

  vpc_id = aws_vpc.eks_vpc.id

  node_groups = {
    example = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
      instance_type    = "m5.large"
    }
  }
}
