terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# ASG/ALB 구성을 위한 Data Source - Default VPC, Default Subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Launch Configuration을 설정을 위한 Security Group
resource "aws_security_group" "myInstanceSG" {
  name = "myInstanceSG"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Configuration을 위한 Data Source(terraform_remote_state) 설정
# https://developer.hashicorp.com/terraform/language/settings/backends/s3
data "terraform_remote_state" "myRemoteState" {
  backend = "s3"
  config = {
    bucket = "bucket-bsc-7979"
    key    = "global/s3/terraform.tfstate"
    region = "us-east-2"
  }
}

# Launch Configuration 설정
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_configuration
resource "aws_launch_configuration" "myLaunchConfiguration" {
  # Region: us-east-2, Ubuntu 20.04 LTS AMI
  image_id        = "ami-06c4532923d4ba1ec"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.myInstanceSG.id]

  # Render the User Data script as a template
  user_data = templatefile("user-data.sh", {
    server_port = 8080
    # terraform apply
    # terraform console
    # > data.terraform_remote_state.myRemoteState
    db_address = data.terraform_remote_state.myRemoteState.outputs.address
    db_port    = data.terraform_remote_state.myRemoteState.outputs.port
  })
  # Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}

# Target Group 생성
resource "aws_lb_target_group" "myALB-TG" {
  name     = "myALB-TG"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

## Auto Scaling Group 생성
resource "aws_autoscaling_group" "MyASG" {
  launch_configuration = aws_launch_configuration.myLaunchConfiguration.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.myALB-TG.arn]
  depends_on        = [aws_lb_target_group.myALB-TG]

  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "myASG"
    propagate_at_launch = true
  }
}

# ALB를 위한 Security Group 생성
resource "aws_security_group" "myALB-SG" {
  name = "myALB-SG"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LB 생성
resource "aws_lb" "myALB" {
  name               = "myALB"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.myALB-SG.id]
}

resource "aws_lb_listener" "myALB-Listener" {
  load_balancer_arn = aws_lb.myALB.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener_rule" "myALB-Listener-Rule" {
  listener_arn = aws_lb_listener.myALB-Listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.myALB-TG.arn
  }
}

