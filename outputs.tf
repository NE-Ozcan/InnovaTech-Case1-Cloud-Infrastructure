output "alb_public_url" {
  description = "De publieke URL van de Application Load Balancer voor Innovatech ticketverkoop"
  value       = "http://${module.compute.alb_dns_name}"
}

output "database_endpoint" {
  description = "Het private connectie-endpoint van Amazon RDS MySQL"
  value       = module.database.db_endpoint
}

output "hub_vpc_id" {
  description = "VPC ID van de centrale Hub"
  value       = module.networking.hub_vpc_id
}

output "web_vpc_id" {
  description = "VPC ID van Spoke 1 (Web Tier)"
  value       = module.networking.spoke_web_vpc_id
}

output "data_vpc_id" {
  description = "VPC ID van Spoke 2 (Data Tier)"
  value       = module.networking.spoke_data_vpc_id
}

output "autoscaling_group_name" {
  description = "Naam van de hybride Auto Scaling Group"
  value       = module.compute.asg_name
}

output "cloudwatch_dashboard" {
  description = "AWS CloudWatch Observability Dashboard (REQ-05)"
  value       = module.compute.cloudwatch_dashboard_name
}

output "cloudwatch_high_cpu_alarm" {
  description = "AWS CloudWatch Piekbelasting Schaal-Alarm (REQ-05)"
  value       = module.compute.high_cpu_alarm_name
}
