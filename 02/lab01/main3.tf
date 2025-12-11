#########################################
# 1. NAT GW 생성 -> Public Subnet
# 2. Private Subnet(myVPC) 생성
# 3. Private Routing Table 생성 및 연결
# 4. SG 생성
# 5. EC2 생성
#########################################

# 1. NAT GW 생성 -> Public Subnet
# EIP 생성된 상태에서 작업
# myPubSubnet에 생성
resource "aws_eip" "myEIP" {
  domain   = "vpc"

  tags = {
    Name = "myEIP"
  }
}

resource "aws_nat_gateway" "myNAT-GW" {
  allocation_id = aws_eip.myEIP.id
  subnet_id     = aws_subnet.myPubSubnet.id
  tags = {
    Name = "myNAT-GW"
  }
  depends_on = [aws_internet_gateway.myIGW]
}

# 2. Private Subnet(myVPC) 생성 
resource "aws_subnet" "myPriSN" {
  vpc_id     = aws_vpc.myVPC.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "myPriSN"
  }
}

# 3. Private Routing Table 생성 및 연결
# NAT GW를 default route로 설정
# myPriSN에 연결
resource "aws_route_table" "myPriRT" {
  vpc_id = aws_vpc.myVPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.myNAT-GW.id
  }

  tags = {
    Name = "myPriRT"
  }
}

resource "aws_route_table_association" "myPriRTassoc" {
  subnet_id      = aws_subnet.myPriSN.id
  route_table_id = aws_route_table.myPriRT.id
}

# 4. SG 생성
# myEC2-2가 사용할 SG
#   - 22/tcp, 80/tcp, 443/tcp [ingress]
#   - All [egress]
resource "aws_security_group" "mySG2" {
  name        = "mySG2"
  description = "Allow TLS inbound 22/tcp, 80/tcp, 443/tcp traffic and all outbound traffic"
  vpc_id      = aws_vpc.myVPC.id

  tags = {
    Name = "mySG2"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mySG2_22" {
  security_group_id = aws_security_group.mySG2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "mySG2_80" {
  security_group_id = aws_security_group.mySG2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "mySG2_443" {
  security_group_id = aws_security_group.mySG2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "mySG2-all" {
  security_group_id = aws_security_group.mySG2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# 5. EC2 생성
# AMI = 아마존 리눅스 2023
# EC2를 새로 생성한 myPriSN에 생성
# mySG2 포함
# SSH를 위한 mykeypair 등록
# user_data {WEB Server}
#   - user_data 변경시 EC2 재생성

resource "aws_instance" "myEC2-2" {
  ami           = "ami-00e428798e77d38d9"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.mySG2.id]
  subnet_id = aws_subnet.myPriSN.id
  key_name = "mykeypair"
  
  user_data_replace_on_change = true
  user_data = <<-EOF
        #!/bin/bash
        dnf install -y httpd mod_ssl
        echo "My Web Server 2 Test Page" > /var/www/html/index.html
        systemctl enable --now httpd
        EOF
  
  tags = {
    Name = "myEC2-2"
  }
}