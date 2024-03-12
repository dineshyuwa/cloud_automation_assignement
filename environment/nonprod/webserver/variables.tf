variable "ami" {
  description = "The ID of the AMI to use for the instance"
  default     = "ami-0c94855ba95c574c8"
}

# Instance type
variable "instance_type" {
  default = {
    "prod"    = "t2.micro"
    "nonprod" = "t2.micro"
  }
  description = "Type of the instance"
  type        = map(string)
}


variable "default_tags" {
  default = {
    "Owner" = "CAAacs",
    "App"   = "Web"
  }
  type        = map(any)
  description = "Default tags to be appliad to all AWS resources"
}

variable "env" {
  default     = "nonprod"
  type        = string
  description = "Deployment Environment"
}

variable "prefix" {
  type        = string
  default     = "nonprod"
  description = "Name prefix"
}