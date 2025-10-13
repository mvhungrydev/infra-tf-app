# Input variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "infra-tf-app"
}

# Venafi Variables
variable "venafi_api_key" {
  description = "Venafi API key for authentication"
  type        = string
  default     = ""
  sensitive   = true
}

variable "venafi_zone" {
  description = "Venafi zone/policy folder for certificate requests (overridden by local.venafi_zone conditional logic)"
  type        = string
  default     = ""
}

variable "venafi_template_alias" {
  description = "Venafi issuing template alias"
  type        = string
  default     = "Default"
}
