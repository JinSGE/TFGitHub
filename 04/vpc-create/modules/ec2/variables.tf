variable "subnet_id" {
  description = "VPC Subnet ID"
  type = string
}

variable "instance_type" {
    default = "t3.micro"
}

variable "ec2_tags" {
    default = {
    Name = "example"
  }
}