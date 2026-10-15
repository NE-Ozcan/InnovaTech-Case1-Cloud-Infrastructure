output "db_endpoint" {
  description = "Connectie endpoint (host:port) van de database"
  value       = "${aws_instance.database_node.private_ip}:3306"
}

output "db_address" {
  description = "Host adres van de private database node"
  value       = aws_instance.database_node.private_ip
}

output "db_name" {
  description = "Naam van de database"
  value       = var.db_name
}
