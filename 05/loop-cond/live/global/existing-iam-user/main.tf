provider "aws" {
  region = "us-east-2"
}

# 사용자 이름 리스트를 변수로 설정
variable "user_names" {
  description = "List of IAM usernames"
  type        = list(string)
  default     = ["user1", "user2", "user3"]
}

# AWS IAM 사용자 생성
resource "aws_iam_user" "createuser" {
  for_each = toset(var.user_names)  # user_names 리스트를 각 키로 사용하여 사용자 생성

  name = each.key  # 각 사용자 이름으로 IAM 사용자 생성
}

output "user_names" {
  value = [for user in aws_iam_user.createuser : user.name]
}
