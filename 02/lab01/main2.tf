# SG 생성
# EC2 생성

# SG 생성
# ingress = 80/tcp, 443/tcp
# egress = 허용

resource "aws_security_group" "mySG" {
  name        = "mySG"
  description = "Allow TLS inbound 80/tcp, 443/tcp traffic and all outbound traffic"
  vpc_id      = aws_vpc.myVPC.id

  tags = {
    Name = "mySG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mySG_22" {
  security_group_id = aws_security_group.mySG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "mySG_80" {
  security_group_id = aws_security_group.mySG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "mySG_443" {
  security_group_id = aws_security_group.mySG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "mySG_all" {
  security_group_id = aws_security_group.mySG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# EC2 생성
# 새로 생성된 mysubsn에 EC2 위치
# SSH를 위한 mykeypair 생성 및 설정.
# user data (80/tcp, 443/tcp)
# => user data 변경되면 EC2 재생성하도록 설정.
# SG(mySG) 포함

# ssh-keygen -t rsa -N "" -f ~/.ssh/mykeypair
resource "aws_key_pair" "mykeypair" {
  key_name   = "mykeypair"
  public_key = file("~/.ssh/mykeypair.pub")
}

resource "aws_instance" "myEC2" {
  ami           = "ami-00e428798e77d38d9"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.mySG.id]
  subnet_id = aws_subnet.myPubSubnet.id
  key_name = "mykeypair"

  user_data_replace_on_change = true
  user_data = <<-EOF
        #!/bin/bash
        dnf install -y httpd mod_ssl
        echo "My Web Server Test Page" > /var/www/html/index.html
        systemctl enable --now httpd
        EOF

  tags = {
    Name = "myEC2"
  }
}
