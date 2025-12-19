variable "vpc_id" {
  description = "The VPC ID to launch the instance in"
  type        = string
}

variable "subnet_id" {
  description = "The Subnet ID to launch the instance in"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the instance"
  type        = string
  default     = "ami-00e428798e77d38d9" # Amazon Linux 2023 (us-east-2)
}

variable "instance_type" {
  description = "The instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The name for the key pair"
  type        = string
  default     = "mymodule-key"
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {
    Name = "mymodule-ec2"
  }
}
