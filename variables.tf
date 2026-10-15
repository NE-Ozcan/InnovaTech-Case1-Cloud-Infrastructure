variable "aws_region" {
  description = "De AWS regio waar alle resources worden uitgerold (Frankfurt voor lage latency & GDPR)"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "De omgevingsnaam (bijv. production, staging, dev)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "De projectnaam voor tagging en naamgeving"
  type        = string
  default     = "innovatech"
}

# --- CIDR Adresseringsplan (Conform Keuzedocument Paragraaf 2.3) ---
variable "hub_cidr" {
  description = "CIDR blok voor de Hub VPC (Centrale Ingress, Egress en Management)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_web_cidr" {
  description = "CIDR blok voor Spoke 1 VPC (Stateless Web Tier met Podman)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke_data_cidr" {
  description = "CIDR blok voor Spoke 2 VPC (Geïsoleerde Data Tier met Amazon RDS)"
  type        = string
  default     = "10.2.0.0/16"
}

# --- Compute & Auto Scaling Variabelen (FinOps) ---
variable "web_instance_type" {
  description = "EC2 instance type voor de web tier baseline"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimaal aantal webservers in de ASG (Multi-AZ baseline)"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximaal aantal webservers tijdens piekverkoop (Spot instances)"
  type        = number
  default     = 8
}

variable "asg_desired_capacity" {
  description = "Gewenst aantal webservers in normale daluren"
  type        = number
  default     = 2
}

# --- Database Variabelen (Amazon RDS Multi-AZ) ---
variable "db_instance_class" {
  description = "Instance class voor de Amazon RDS MySQL instance"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Naam van de initiële applicatiedatabase"
  type        = string
  default     = "innovatech_tickets"
}

variable "db_username" {
  description = "Master database administrator gebruikersnaam"
  type        = string
  default     = "innovatech_admin"
}

variable "db_password" {
  description = "Master database administrator wachtwoord"
  type        = string
  sensitive   = true
  default     = "Innovatech2026SecurePass!"
}
