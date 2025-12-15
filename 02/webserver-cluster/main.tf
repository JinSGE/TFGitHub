#######################################
# 0. Intra
# 1. ALB
# * SG 생성
# * TG 생성
# * ALB 생성
# * ALB Listener 생성
# * ALB Listener Rule 생성
# 2. ASG
# * SG 생성
# * launch Templete 생성
# * ASG 생성
#######################################

#######################################
# 0. Infra
#######################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
data "aws_vpc" "default" {
  default = true
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

#######################################
# 1. ALB
#######################################
# * SG 생성
# * TG 생성
# * ALB 생성
# * ALB Listener 생성
# * ALB Listener Rule 생성

#######################################
# * SG 생성
#######################################
# ingress: 80/tcp, egress: all
resource "aws_security_group" "myalb_sg" {
  name        = "myalb_sg"
  description = "Allow TLS inbound 80/tcp traffic and all outbound traffic"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "myalb_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_myalb_80" {
  security_group_id = aws_security_group.myalb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.server_port
  to_port           = var.server_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_myalb_all" {
  security_group_id = aws_security_group.myalb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#######################################
# * TG 생성
#######################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "myalb_tg" {
  name     = "myalb-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

#######################################
# * ALB 생성
#######################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.myalb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "myalb"
  }
}

#######################################
# * ALB Listener 생성
#######################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
resource "aws_lb_listener" "myalb_listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = var.server_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myalb_tg.arn
  }
}

#######################################
# * ALB Listener Rule 생성
#######################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule
resource "aws_lb_listener_rule" "myalb_listener_rule" {
  listener_arn = aws_lb_listener.myalb_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myalb_tg.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

#######################################
# 2. ASG
#######################################
# * SG 생성
# * launch Templete 생성
# * ASG 생성

#######################################
# * SG 생성
#######################################
# ingress: 80/tcp, egress: all
resource "aws_security_group" "myasg_sg" {
  name        = "myasg_sg"
  description = "Allow TLS inbound 80/tcp traffic and all outbound traffic"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "myasg_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_myasg_80" {
  security_group_id = aws_security_group.myasg_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.server_port
  to_port           = var.server_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_myasg_all" {
  security_group_id = aws_security_group.myasg_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#######################################
# * launch Templete 생성
#######################################
# * ami id
# * launch template 생성

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
data "aws_ami" "amazonlinux2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.9.*.0-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
resource "aws_launch_template" "mylt" {
  name = "mylt"

  image_id               = data.aws_ami.amazonlinux2023.id
  instance_type          = var.vcpu2_MEM1gb
  vpc_security_group_ids = [aws_security_group.myasg_sg.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "mylt"
    }
  }

  user_data = filebase64("./user_data.sh")
}

#######################################
# * ASG 생성
#######################################
# * target_group_arns
# * depends_on
resource "aws_autoscaling_group" "myasg" {
  vpc_zone_identifier = data.aws_subnets.default.ids
  desired_capacity    = 2
  max_size            = 2
  min_size            = 2

  target_group_arns = [aws_lb_target_group.myalb_tg.arn]
  depends_on        = [aws_lb_target_group.myalb_tg]

  launch_template {
    id      = aws_launch_template.mylt.id
    version = "$Latest" 
  }
}



