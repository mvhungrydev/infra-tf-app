# Main Terraform configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    venafi = {
      source  = "Venafi/venafi"
      version = "~> 0.23"
    }
  }
  
  # S3 backend configuration
  backend "s3" {
    bucket = "mv-tf-pipeline-state"
    key    = "infra-tf-app/terraform.tfstate"
    region = "us-east-1"
    # Note: No DynamoDB table for state locking as requested
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# Configure the Venafi Provider
provider "venafi" {
  # API key retrieved from AWS Secrets Manager via CodeBuild
  # The TF_VAR_venafi_api_key environment variable is set in buildspec.yml
  api_key = var.venafi_api_key
  zone    = local.venafi_zone
}

# Local values for conditional logic
locals {
  # Conditional Venafi zone based on environment (including issuing template alias)
  venafi_zone = var.environment == "prod" ? "aws_12345_730335317277_prod\\${var.venafi_template_alias}" : "aws_12345_730335317277_lle\\${var.venafi_template_alias}"
}