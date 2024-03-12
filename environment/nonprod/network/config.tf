provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "acs730-assignment-143871234"
    key    = "nonprod/network/terraform.tfstate"
    region = "us-east-1"
  }
}
