############################################
# 변수 설정 (Variables)
############################################

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ami_id" {
  description = "EC2 AMI ID (Amazon Linux 2023)"
  type        = string
  default     = "ami-00e428798e77d38d9"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "데이터베이스 마스터 사용자 이름"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "데이터베이스 마스터 암호"
  type        = string
  sensitive   = true
  default     = "password1234"
}
