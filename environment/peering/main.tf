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

data "aws_caller_identity" "current" {}

data "aws_vpc" "vpc1" {
  filter {
    name   = "tag:Name"
    values = ["prod-public-subnet"]
  }
}

data "aws_vpc" "vpc2" {
  filter {
    name   = "tag:Name"
    values = ["nonprod-public-subnet"]
  }
}

data "aws_route_table" "non_main1" {
  filter {
    name   = "tag:Name"
    values = ["nonprod-route-public-subnets"]
  }
}

data "aws_route_table" "non_main2" {
  filter {
    name   = "tag:Name"
    values = ["prod-route-public-subnets"]
  }
}

resource "aws_vpc_peering_connection" "peer1" {
  vpc_id        = data.aws_vpc.vpc1.id
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_vpc_id   = data.aws_vpc.vpc2.id
  auto_accept   = true
}

resource "aws_route" "non_main_route1" {
  route_table_id            = data.aws_route_table.non_main1.id
  destination_cidr_block    = data.aws_vpc.vpc1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer1.id
}

resource "aws_route" "non_main_route2" {
  route_table_id            = data.aws_route_table.non_main2.id
  destination_cidr_block    = data.aws_vpc.vpc2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer1.id
}

resource "aws_route" "vpc1-vpc2" {
  route_table_id            = data.aws_vpc.vpc1.main_route_table_id
  destination_cidr_block    = data.aws_vpc.vpc2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer1.id
}


resource "aws_route" "vpc2-vpc1" {
  route_table_id            = data.aws_vpc.vpc2.main_route_table_id
  destination_cidr_block    = data.aws_vpc.vpc1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer1.id
}

