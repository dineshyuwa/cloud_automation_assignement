terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27"
    }
  }

  required_version = ">=0.14"
}
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
}

resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-public-subnet"
    }
  )
}

resource "aws_subnet" "public_subnet" {
  count             = var.env == "nonprod" ? length(var.public_cidr_blocks) : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-public-subnet-${count.index}"
    }
  )
}

resource "aws_subnet" "private_subnet" {
  count             = length(var.private_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    local.default_tags, {
      Name = "${var.prefix}-private-subnet-${count.index}"
    }
  )
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-igw"
    }
  )
}

resource "aws_eip" "nat" {
 count = var.env == "nonprod" ? length(var.public_cidr_blocks) : 0
  vpc   = true
}

resource "aws_nat_gateway" "nat" {
  count         = var.env == "nonprod" ? length(var.public_cidr_blocks) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "my_alb" {
  count = var.env == "nonprod" ? 1 : 0 
  name               = "${var.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.env == "nonprod" ? aws_subnet.public_subnet[*].id : []

  security_groups    = [aws_security_group.alb_sg.id]

  tags = merge(
    local.default_tags,
    {
      Name = "${var.prefix}-alb"
    }
  )
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "${var.prefix}-target-group"
  port     = 80
  protocol = "HTTP"

  vpc_id = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "my_listener" {
  count = var.env == "nonprod" ? 1 : 0

  load_balancer_arn = aws_lb.my_alb[count.index].arn  
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}


resource "aws_route_table" "private" {
  count  = length(var.private_cidr_blocks)
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.prefix}-route-private-subnets-${count.index}"
  }
}

resource "aws_route" "private" {
  count = var.env == "nonprod" ? length(var.private_cidr_blocks) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = var.env == "nonprod" ? aws_nat_gateway.nat[count.index].id : aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-route-public-subnets"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = var.env == "nonprod" ? length(aws_subnet.public_subnet.*.id) : length(aws_subnet.private_subnet.*.id)
  subnet_id      = var.env == "nonprod" ? aws_subnet.public_subnet[count.index].id : aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.public.id
}
