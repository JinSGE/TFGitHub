variable "vpc_cidr" {
    description = "VPC_CIDR_Block(ex: 10.0.0.0/16)"
    type = string
    default = "10.0.0.0/16"
}

variable "subnet_cidr" {
    description = "Subnet_CIDR_Block(ex: 10.0.1.0/24)"
    type = string
    default = "10.0.1.0/24"
}
variable "subnet_tags" {
    default = {
        Name = "main"
    }
}