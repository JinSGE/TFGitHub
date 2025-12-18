
# Data Source: 최신 Amazon Linux 2023 AMI 조회
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################################
# VPC 리소스 생성
############################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr    # VPC의 IP 대역폭 설정
  enable_dns_support   = true          # DNS 지원 활성화
  enable_dns_hostnames = true          # DNS 호스트네임 활성화

  tags = {
    Name = "main-vpc"
  }
}

############################################
# 인터넷 게이트웨이 (IGW)
############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

############################################
# 퍼블릭 서브넷 (ALB 및 NAT 게이트웨이용)
############################################
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true # 인스턴스 시작 시 퍼블릭 IP 자동 할당

  tags = {
    Name = "public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-b"
  }
}

############################################
# 프라이빗 서브넷 (EC2 애플리케이션 및 DB용)
############################################
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "private-b"
  }
}

############################################
# NAT 게이트웨이 (프라이빗 인스턴스의 외부 인터넷 통신용)
############################################
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id # NAT 게이트웨이는 퍼블릭 서브넷에 위치해야 함

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.igw] # IGW가 생성된 후 생성
}

############################################
# 라우팅 테이블 (퍼블릭)
############################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id # 모든 트래픽을 IGW로 라우팅
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

############################################
# 라우팅 테이블 (프라이빗)
############################################
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id # 외부 트래픽을 NAT 게이트웨이로 라우팅
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b_assoc" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

############################################
# 보안 그룹 (Security Groups) 생성
############################################
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 모든 IP에서의 80번 포트 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# EC2 보안 그룹
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # ALB 보안 그룹에서만 접근 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# DB 보안 그룹
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] # EC2 보안 그룹에서만 3306 포트 접근 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

############################################
# 애플리케이션 로드 밸런서 (ALB) 구성
############################################
resource "aws_lb" "alb" {
  name               = "main-alb"
  internal           = false # 인터넷 연결 가능 (External)
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

resource "aws_lb_target_group" "tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/" # 헬스 체크 경로
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward" # 타겟 그룹으로 트래픽 전달
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

############################################
# EC2 오토 스케일링 (Auto Scaling) 설정
############################################
resource "aws_launch_template" "lt" {
  name_prefix   = "web-lt"
  # 사용할 AMI ID (us-east-2 Amazon Linux 2023)
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false # 프라이빗 서브넷에 배치하므로 false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  # 사용자 데이터 (웹 서버 설치 및 실행 스크립트)
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform AWS Architecture</h1>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-instance"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  desired_capacity = 2 # 원하는 인스턴스 수
  max_size         = 2 # 최대 인스턴스 수
  min_size         = 2 # 최소 인스턴스 수
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn] # ALB 타겟 그룹 연결

  tag {
    key                 = "Name"
    value               = "web-asg-node"
    propagate_at_launch = true
  }
}

############################################
# RDS 데이터베이스 생성 (Multi-AZ)
############################################
resource "aws_db_subnet_group" "db_subnet" {
  name = "db-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "aws_db_instance" "db" {
  identifier              = "main-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  username                = var.db_username
  password                = var.db_password
  multi_az                = true # 멀티 AZ 배포 활성화
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet.name
}

