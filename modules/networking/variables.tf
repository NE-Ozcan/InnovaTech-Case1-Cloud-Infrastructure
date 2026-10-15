variable "project_name" {
  description = "Project prefix voor resources"
  type        = string
}

variable "environment" {
  description = "Environment naam"
  type        = string
}

variable "hub_cidr" {
  description = "CIDR voor Hub VPC"
  type        = string
}

variable "spoke_web_cidr" {
  description = "CIDR voor Spoke 1 Web VPC"
  type        = string
}

variable "spoke_data_cidr" {
  description = "CIDR voor Spoke 2 Data VPC"
  type        = string
}
