provider "aws" {
  region = var.aws_region
}

module "my_vpc" {
  source = "../modules/vpc"

  # vpc_cidr = "192.168.10.0/24"
  # subnet_cidr = "192.168.10.0/25"
}

module "my_ec2" {
  source = "../modules/ec2"

  subnet_id = module.my_vpc.subnet_id
}
