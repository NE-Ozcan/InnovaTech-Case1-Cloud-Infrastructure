terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # In een productieomgeving wordt de state extern vergrendeld via S3 en DynamoDB (REQ-06)
  # backend "s3" {
  #   bucket         = "innovatech-opentofu-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "innovatech-tofu-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "OpenTofu"
      Course      = "MA-NCA"
    }
  }
}
