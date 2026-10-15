variable "project_name" {
  description = "Project prefix voor resources"
  type        = string
}

variable "environment" {
  description = "Environment naam"
  type        = string
}

variable "hub_vpc_id" {
  description = "VPC ID van de Hub (voor ALB)"
  type        = string
}

variable "spoke_web_vpc_id" {
  description = "VPC ID van Spoke 1 (voor Target Group)"
  type        = string
}

variable "web_public_subnet_ids" {
  description = "Publieke subnet IDs in Spoke Web (voor ALB)"
  type        = list(string)
}

variable "web_private_subnet_ids" {
  description = "Private subnet IDs in Spoke 1 (voor ASG)"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security Group ID van de ALB"
  type        = string
}

variable "web_sg_id" {
  description = "Security Group ID van de Web Tier"
  type        = string
}

variable "web_instance_type" {
  description = "Instance type voor web servers (t3.micro)"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimaal aantal webservers"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximaal aantal webservers tijdens piekverkoop"
  type        = number
  default     = 8
}

variable "asg_desired_capacity" {
  description = "Gewenst aantal webservers in daluren"
  type        = number
  default     = 2
}
