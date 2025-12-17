#########################################################
# 0) terraform & provider 설정
# 1) VPC 생성
# 2) IGW 생성 및 연결
# 3) Public Route Table 생성
# 4) Public Subnet 2개 생성
# 5) Security Group 생성 (ALB / EC2)
# 6) EC2 2대 생성
# 7) EIP 할당
# 8) ALB Target Group 생성 및 EC2 연결
# 9) ALB + Listener 생성
#########################################################

############################
# 0) Terraform & Provider
############################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

############################
# 1) VPC
############################
resource "aws_vpc" "MyVPC" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "My-VPC"
  }
}

############################
# 2) Internet Gateway
############################
resource "aws_internet_gateway" "MyIGW" {
  vpc_id = aws_vpc.MyVPC.id

  tags = {
    Name = "My-IGW"
  }
}

############################
# 3) Public Route Table
############################
resource "aws_route_table" "MyPublicRT" {
  vpc_id = aws_vpc.MyVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.MyIGW.id
  }

  tags = {
    Name = "My-Public-RT"
  }
}

############################
# 4) Public Subnets
############################
resource "aws_subnet" "MySubnet1" {
  vpc_id                  = aws_vpc.MyVPC.id
  availability_zone       = "us-east-2a"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "My-Public-SN-1"
  }
}

resource "aws_subnet" "MySubnet2" {
  vpc_id                  = aws_vpc.MyVPC.id
  availability_zone       = "us-east-2b"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "My-Public-SN-2"
  }
}

resource "aws_route_table_association" "RTAssoc1" {
  subnet_id      = aws_subnet.MySubnet1.id
  route_table_id = aws_route_table.MyPublicRT.id
}

resource "aws_route_table_association" "RTAssoc2" {
  subnet_id      = aws_subnet.MySubnet2.id
  route_table_id = aws_route_table.MyPublicRT.id
}

############################
# 5) Security Groups
############################
# ALB SG
resource "aws_security_group" "ALBSG" {
  name   = "ALB-SG"
  vpc_id = aws_vpc.MyVPC.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB-SG"
  }
}

# EC2 SG
resource "aws_security_group" "WEBSG" {
  name   = "WEB-SG"
  vpc_id = aws_vpc.MyVPC.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ALBSG.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WEB-SG"
  }
}

############################
# 6) EC2 Instances
############################
resource "aws_instance" "MYEC21" {
  ami                    = "ami-083eed19fc801d7a4"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.MySubnet1.id
  vpc_security_group_ids = [aws_security_group.WEBSG.id]

  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname EC2-1
    yum -y install httpd
    systemctl enable --now httpd
    echo "<h1>CloudNet@ EC2-1 Web Server</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "EC2-1"
  }
}

resource "aws_instance" "MYEC22" {
  ami                    = "ami-083eed19fc801d7a4"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.MySubnet2.id
  vpc_security_group_ids = [aws_security_group.WEBSG.id]

  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname EC2-2
    yum -y install httpd
    systemctl enable --now httpd
    echo "<h1>CloudNet@ EC2-2 Web Server</h1>" > /var/www/html/index.html
  EOF

  tags = {
    Name = "EC2-2"
  }
}

############################
# 7) Elastic IP
############################
resource "aws_eip" "MyEIP1" {
  instance = aws_instance.MYEC21.id
  domain   = "vpc"
}

resource "aws_eip" "MyEIP2" {
  instance = aws_instance.MYEC22.id
  domain   = "vpc"
}

############################
# 8) ALB Target Group
############################
resource "aws_lb_target_group" "ALBTG" {
  name     = "My-ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.MyVPC.id
}

resource "aws_lb_target_group_attachment" "TGAttach1" {
  target_group_arn = aws_lb_target_group.ALBTG.arn
  target_id        = aws_instance.MYEC21.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "TGAttach2" {
  target_group_arn = aws_lb_target_group.ALBTG.arn
  target_id        = aws_instance.MYEC22.id
  port             = 80
}

############################
# 9) ALB & Listener
############################
resource "aws_lb" "MyALB" {
  name               = "My-ALB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALBSG.id]
  subnets            = [
    aws_subnet.MySubnet1.id,
    aws_subnet.MySubnet2.id
  ]
}

resource "aws_lb_listener" "ALBListener" {
  load_balancer_arn = aws_lb.MyALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ALBTG.arn
  }
}

############################
# Output
############################
output "ALB_DNS_Name" {
  value = aws_lb.MyALB.dns_name
}
