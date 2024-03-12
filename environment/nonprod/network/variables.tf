variable "default_tags" {
  default = {
    "Owner" = "CAAacs",
    "App"   = "Web"
  }
  type        = map(any)
  description = "Default tags to be appliad to all AWS resources"
}

variable "prefix" {
  type        = string
  default     = "nonprod"
  description = "Name prefix"
}

variable "public_subnet_cidrs" {
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
  type        = list(string)
  description = "Public Subnet CIDRs"
}

variable "private_subnet_cidrs" {
  default     = ["10.1.2.0/24", "10.1.3.0/24"]
  type        = list(string)
  description = "Private Subnet CIDRs"
}

variable "vpc_cidr" {
  default     = "10.1.0.0/16"
  type        = string
  description = "VPC to host static web site"
}

variable "env" {
  default     = "nonprod"
  type        = string
  description = "Deployment Environment"
}

