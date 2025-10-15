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

variable "venafi_cloud_url" {
  description = "Venafi Control Plane (VCP) URL"
  type        = string
  default     = "https://api.venafi.cloud"
}

# Certificate Variables
variable "certificate_count" {
  description = "Number of certificates to create"
  type        = number
  default     = 3
}

variable "certificate_domain" {
  description = "Domain name for certificates (will be used with random prefix)"
  type        = string
  default     = "example.com"
}

variable "certificate_algorithm" {
  description = "Certificate algorithm"
  type        = string
  default     = "RSA"
  
  validation {
    condition     = contains(["RSA", "ECDSA"], var.certificate_algorithm)
    error_message = "Algorithm must be either RSA or ECDSA."
  }
}

variable "certificate_rsa_bits" {
  description = "RSA key size (only used if algorithm is RSA)"
  type        = number
  default     = 2048
  
  validation {
    condition     = contains([2048, 3072, 4096], var.certificate_rsa_bits)
    error_message = "RSA bits must be 2048, 3072, or 4096."
  }
}

variable "certificate_valid_days" {
  description = "Certificate validity period in days"
  type        = number
  default     = 90
}
