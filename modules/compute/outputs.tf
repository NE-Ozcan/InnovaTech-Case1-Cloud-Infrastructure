output "alb_dns_name" {
  description = "Publieke DNS naam van de Application Load Balancer"
  value       = aws_lb.main_alb.dns_name
}

output "alb_arn" {
  description = "ARN van de Application Load Balancer"
  value       = aws_lb.main_alb.arn
}

output "asg_name" {
  description = "Naam van de Auto Scaling Group"
  value       = aws_autoscaling_group.web_asg.name
}

output "target_group_arn" {
  description = "ARN van de Target Group"
  value       = aws_lb_target_group.web_tg.arn
}

output "cloudwatch_dashboard_name" {
  description = "Naam van het AWS CloudWatch Observability Dashboard"
  value       = aws_cloudwatch_dashboard.observability.dashboard_name
}

output "high_cpu_alarm_name" {
  description = "Naam van het CloudWatch Schaal-Alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}
