resource "aws_instance" "myEC2" {
  ami           = "ami-00e428798e77d38d9"
  instance_type = "t3.micro"

  tags = {
    Name = "myEC2"
  }
}