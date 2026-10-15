variable "project_name" {
  description = "Project prefix voor resources"
  type        = string
}

variable "environment" {
  description = "Environment naam"
  type        = string
}

variable "data_private_subnet_ids" {
  description = "Private Subnet IDs in Spoke 2 Data VPC"
  type        = list(string)
}

variable "db_sg_id" {
  description = "Security Group ID van de Database"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance klasse"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Naam van de database"
  type        = string
  default     = "innovatech_tickets"
}

variable "db_username" {
  description = "Database administrator gebruikersnaam"
  type        = string
  default     = "innovatech_admin"
}

variable "db_password" {
  description = "Database administrator wachtwoord"
  type        = string
  sensitive   = true
}
