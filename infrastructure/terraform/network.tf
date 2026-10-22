resource "aws_vpc" "olist" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "olist-dev"
    Project = "olist-streaming-platform"
  }
}

resource "aws_subnet" "olist" {
  vpc_id     = aws_vpc.olist.id
  cidr_block = "10.20.1.0/24"

  tags = {
    Name = "olist-dev-public"
  }
}

resource "aws_internet_gateway" "olist" {
  vpc_id = aws_vpc.olist.id

  tags = {
    Name = "olist-dev"
  }
}

resource "aws_route_table" "olist" {
  vpc_id = aws_vpc.olist.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.olist.id
  }

  tags = {
    Name = "olist-dev-public"
  }
}

resource "aws_route_table_association" "olist" {
  subnet_id      = aws_subnet.olist.id
  route_table_id = aws_route_table.olist.id
}

resource "aws_security_group" "olist" {
  name_prefix = "olist-dev-"
  description = "No inbound access; administration through Session Manager"
  vpc_id      = aws_vpc.olist.id

  ingress = []

  egress {
    description = "Allow outbound connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "olist-dev"
  }
}