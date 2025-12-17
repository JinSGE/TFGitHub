############################
# 1. S3 bucket 생성         #
# 2. DynamoDB Table 생성    #
############################
# resource "aws_s3_bucket" "my_tfstate" {
#   bucket = "myjse-1216"

#   tags = {
#     Name        = "myjse-1216"
#   }
# }

resource "aws_dynamodb_table" "my_tflocks" {
  name           = "my_tflocks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "my_tflocks"
  }
}