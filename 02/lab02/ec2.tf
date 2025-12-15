###############################
# 1. Provider
###############################
provider "aws" {
  region = "us-east-2"
}

###############################
# 2. AMI Data Source
# - Amazon Linux 2023
###############################
data "aws_ami" "amazon2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.9.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon 공식 계정
}

###############################
# 3. Security Group
###############################
resource "aws_security_group" "mysg" {
  name        = "mysg"
  description = "Allow SSH inbound and all outbound"

  tags = {
    Name = "mysg"
  }
}

# SSH Inbound (22)
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.mysg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# All Outbound
resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.mysg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

###############################
# 4. EC2 Instance
###############################
resource "aws_instance" "myInstance" {
  ami           = data.aws_ami.amazon2023.id
  instance_type = "t3.micro"
  key_name      = "mykeypair"

  vpc_security_group_ids = [
    aws_security_group.mysg.id
  ]

  tags = {
    Name = "myInstance"
  }
}

###############################
# 5. Outputs
###############################
output "ami_id" {
  description = "AMI ID used by EC2"
  value       = aws_instance.myInstance.ami
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.myInstance.id
}

output "public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.myInstance.public_ip
}

output "public_dns" {
  description = "EC2 Public DNS"
  value       = aws_instance.myInstance.public_dns
}
