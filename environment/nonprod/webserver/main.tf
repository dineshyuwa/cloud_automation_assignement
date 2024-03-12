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

data "terraform_remote_state" "public_subnet" {
  backend = "s3"
  config = {
    bucket = "acs730-assignment-143871234"
    key    = "nonprod/network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  default_tags = merge(var.default_tags, { "env" = var.env })
  name_prefix  = "${var.prefix}-${var.env}"
}

resource "aws_instance" "public_instance" {

  count                       = length(data.terraform_remote_state.public_subnet.outputs.public_subnet_ids)
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.assignment.key_name
  security_groups             = [aws_security_group.acs730.id]
  subnet_id                   = data.terraform_remote_state.public_subnet.outputs.public_subnet_ids[count.index]
  associate_public_ip_address = true

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-Amazon-Linux"
    }
  )
}

resource "aws_instance" "private_instance" {

  count           = length(data.terraform_remote_state.public_subnet.outputs.private_subnet_ids)
  ami             = data.aws_ami.latest_amazon_linux.id
  instance_type   = lookup(var.instance_type, var.env)
  key_name        = aws_key_pair.assignment.key_name
  security_groups = [aws_security_group.acs730.id]
  subnet_id       = data.terraform_remote_state.public_subnet.outputs.private_subnet_ids[count.index]
  user_data       = <<-EOF
  #!/bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
echo "Hello, World!" > /var/www/html/index.html
sudo systemctl start httpd
sudo systemctl enable httpd
EOF


  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-Amazon-Linux"
    }
  )
}

resource "aws_key_pair" "assignment" {
  key_name   = var.prefix
  public_key = file("${var.prefix}.pub")
}

resource "aws_security_group" "acs730" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = data.terraform_remote_state.public_subnet.outputs.vpc_id

  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "ICMP from everywhere"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-EBS"
    }
  )
}

resource "aws_volume_attachment" "ebs_public_instance" {
  count       = length(aws_instance.public_instance)
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.web_ebs[count.index].id
  instance_id = aws_instance.public_instance[count.index].id
}

resource "aws_ebs_volume" "web_ebs" {
  count             = length(aws_instance.public_instance)
  availability_zone = aws_instance.public_instance[count.index].availability_zone
  size              = 40

  tags = merge(local.default_tags,
    {
      "Name" = "${var.prefix}-EBS-${count.index}"
    }
  )
}

resource "aws_eip" "bastion_eip" {
  count    = length(aws_instance.public_instance)
  instance = aws_instance.public_instance[count.index].id
}
