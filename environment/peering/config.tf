terraform {
  backend "s3" {
    bucket = "acs730-assignment-143871234"
    key    = "peering/peeringconnection/terraform.tfstate"
    region = "us-east-1"
  }
}