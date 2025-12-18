############################################
# 출력 값 (Outputs)
############################################
output "alb_dns_name" {
  description = "ALB의 DNS 주소"
  value       = aws_lb.alb.dns_name
}
