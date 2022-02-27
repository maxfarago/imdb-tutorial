### VPC & GATEWAYS ###
resource "aws_vpc" "vpc1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc1"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "main"
  }
}

resource "aws_eip" "nat_ip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public1.id
  allocation_id = aws_eip.nat_ip.id
  depends_on    = [aws_internet_gateway.gw]
}

### SUBNETS ###
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az1
  map_public_ip_on_launch = true
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.vpc1.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az2
  map_public_ip_on_launch = true

  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az1

  tags = {
    Name = "private"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az2

  tags = {
    Name = "private"
  }
}

### DB SUBNET GROUP ###
resource "aws_db_subnet_group" "private" {
  name       = "private"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

### ROUTE TABLES ###
resource "aws_route_table" "primary" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "primary"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.primary.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.primary.id
}

resource "aws_route_table" "private_to_nat" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "private_to_nat"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private_to_nat.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private_to_nat.id
}

### ROUTES ###
resource "aws_route" "to_outside" {
  route_table_id         = aws_route_table.primary.id
  destination_cidr_block = "0.0.0.0/0"
  depends_on             = [aws_route_table.primary]
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "private_to_nat" {
  route_table_id         = aws_route_table.private_to_nat.id
  destination_cidr_block = "0.0.0.0/0"
  depends_on             = [aws_route_table.private_to_nat]
  nat_gateway_id         = aws_nat_gateway.nat.id
}

### SECURITY GROUPS ###
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description      = "TLS from public"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "TLS to IMDB API"
    from_port        = 3000
    to_port          = 3000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "SSH from Joel"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group" "web_servers" {
  name        = "web_servers"
  description = "servers behind load balancer"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description     = "requests from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_tls.id]
  }

  ingress {
    cidr_blocks      = ["0.0.0.0/0", ]
    from_port        = 443
    ipv6_cidr_blocks = ["::/0", ]
    protocol         = "tcp"
    to_port          = 443
    security_groups  = [aws_security_group.allow_tls.id]
  }

  ingress {
    from_port       = 22
    protocol        = "tcp"
    to_port         = 22
    security_groups = [aws_security_group.allow_tls.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web_servers"
  }
}

resource "aws_security_group" "imdb_sg" {
  name        = "imdb_sg"
  description = "security group for the IMDB DB instance"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    description     = "requests from API"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_tls.id]
  }

  ingress {
    from_port       = 22
    protocol        = "tcp"
    to_port         = 22
    security_groups = [aws_security_group.allow_tls.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name    = "IMDB_DB_SG"
    Project = "IMDB"
  }
}
