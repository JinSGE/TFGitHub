output "ec2_public_ip" {
  description = "Public IP of the created EC2 instance"
  value       = module.ec2.instance_public_ip
}

output "private_key_path" {
  description = "Path to the private key"
  value       = module.ec2.private_key_path
}
