variable "project_name" {
  description = "Project prefix voor resources"
  type        = string
}

variable "environment" {
  description = "Environment naam"
  type        = string
}

variable "hub_vpc_id" {
  description = "VPC ID van de Hub"
  type        = string
}

variable "spoke_web_vpc_id" {
  description = "VPC ID van Spoke 1 (Web)"
  type        = string
}

variable "spoke_data_vpc_id" {
  description = "VPC ID van Spoke 2 (Data)"
  type        = string
}

variable "hub_cidr" {
  description = "CIDR blok van de Hub VPC"
  type        = string
}

variable "spoke_web_cidr" {
  description = "CIDR blok van Spoke 1 (Web)"
  type        = string
}

variable "spoke_data_cidr" {
  description = "CIDR blok van Spoke 2 (Data)"
  type        = string
}
