output "hub_vpc_id" {
  description = "VPC ID van de Hub"
  value       = aws_vpc.hub.id
}

output "spoke_web_vpc_id" {
  description = "VPC ID van Spoke 1 (Web)"
  value       = aws_vpc.spoke_web.id
}

output "spoke_data_vpc_id" {
  description = "VPC ID van Spoke 2 (Data)"
  value       = aws_vpc.spoke_data.id
}

output "hub_public_subnet_ids" {
  description = "Publieke subnets in de Hub VPC"
  value       = [aws_subnet.hub_public_1.id, aws_subnet.hub_public_2.id]
}

output "web_public_subnet_ids" {
  description = "Publieke subnets in de Web VPC (voor ALB)"
  value       = [aws_subnet.web_public_1.id, aws_subnet.web_public_2.id]
}

output "hub_mgmt_subnet_id" {
  description = "Management subnet in de Hub VPC (voor CI/CD runner)"
  value       = aws_subnet.hub_mgmt.id
}

output "web_private_subnet_ids" {
  description = "Private subnets in Spoke 1 (voor Webservers ASG)"
  value       = [aws_subnet.web_private_1.id, aws_subnet.web_private_2.id]
}

output "data_private_subnet_ids" {
  description = "Private subnets in Spoke 2 (voor Amazon RDS Subnet Group)"
  value       = [aws_subnet.data_private_1.id, aws_subnet.data_private_2.id]
}

output "peering_hub_web_id" {
  description = "Peering connection ID tussen Hub en Web"
  value       = aws_vpc_peering_connection.hub_to_web.id
}

output "peering_web_data_id" {
  description = "Peering connection ID tussen Web en Data"
  value       = aws_vpc_peering_connection.web_to_data.id
}
