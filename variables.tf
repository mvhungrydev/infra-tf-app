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
  default     = "terraform-cicd"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "123456789012"
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

# EC2 Variables for Venafi vSatellite
variable "vsatellite_instance_type" {
  description = "EC2 instance type for Venafi vSatellite"
  type        = string
  default     = "t3.large"

  validation {
    condition = contains([
      "t3.large", "t3.xlarge", 
      "m5.large", "m5.xlarge",
      "c5.large", "c5.xlarge"
    ], var.vsatellite_instance_type)
    error_message = "Instance type must meet vSatellite minimum requirements (2+ vCPUs, 8+ GB RAM)."
  }
}

variable "vsatellite_root_volume_size" {
  description = "Root volume size in GB for vSatellite instance"
  type        = number
  default     = 50

  validation {
    condition     = var.vsatellite_root_volume_size >= 20
    error_message = "Root volume size must be at least 20 GB for vSatellite."
  }
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for SSH access to vSatellite instance"
  type        = string
  default     = ""
}

variable "vsatellite_name" {
  description = "Name tag for the vSatellite instance"
  type        = string
  default     = "venafi-vsatellite"
}
