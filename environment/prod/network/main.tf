module "vpc-prod" {
  source              = "../../Modules/network"
  env                 = var.env
  vpc_cidr            = var.vpc_cidr
  private_cidr_blocks = var.private_subnet_cidrs
  prefix              = var.prefix
  default_tags        = var.default_tags
}
