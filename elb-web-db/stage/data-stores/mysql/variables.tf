variable "dbuser" {
  description = "The username for the database"
  type        = string
  sensitive   = true
}

variable "dbpassword" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}
