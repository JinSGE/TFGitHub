provider "aws" {
  region = var.region
}

module "net" {
  source = "./modules/net"

  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  availability_zone  = "${var.region}a"
}

module "ec2" {
  source = "./modules/ec2"

  vpc_id        = module.net.vpc_id
  subnet_id     = module.net.public_subnet_id
  instance_type = "t3.micro"
  key_name      = "my-root-key"
}
