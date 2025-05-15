provider "aws" {
  region = "eu-south-2"
}

resource "aws_vpc" "wordpress" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "WordpressVPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wordpress.id

  tags = {
    Name = "WordpressVPC-IGW"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.wordpress.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-south-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "WP_PublicSubnet1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.wordpress.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-south-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "WP_PublicSubnet2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.wordpress.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-south-2a"

  tags = {
    Name = "WP_PrivateSubnet1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.wordpress.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-south-2b"

  tags = {
    Name = "WP_PrivateSubnet2"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.wordpress.id

  tags = {
    Name = "WP_PublicRouteTable"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.wordpress.id

  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}