output "alb_sg_id" {
  description = "Security Group ID van de ALB"
  value       = aws_security_group.alb_sg.id
}

output "web_sg_id" {
  description = "Security Group ID van de Web Tier"
  value       = aws_security_group.web_sg.id
}

output "db_sg_id" {
  description = "Security Group ID van de Database Tier"
  value       = aws_security_group.db_sg.id
}

output "runner_sg_id" {
  description = "Security Group ID van de CI/CD Runner"
  value       = aws_security_group.runner_sg.id
}
