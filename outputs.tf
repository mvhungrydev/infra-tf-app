# Output values
# Certificate outputs
output "certificate_common_names" {
  description = "Common names of all created certificates"
  value       = venafi_certificate.certificates[*].common_name
}

output "certificate_ids" {
  description = "Certificate IDs of all created certificates"
  value       = venafi_certificate.certificates[*].certificate_id
}

output "certificate_dns" {
  description = "Certificate DNs of all created certificates"
  value       = venafi_certificate.certificates[*].certificate_dn
}

output "certificate_count" {
  description = "Total number of certificates created"
  value       = length(venafi_certificate.certificates)
}

# Variable outputs (excluding sensitive API key)
# AWS Configuration Variables
output "aws_region" {
  description = "AWS region for resources"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Name of the project"
  value       = var.project_name
}

# Venafi Configuration Variables
output "venafi_zone" {
  description = "Venafi zone/policy folder for certificate requests"
  value       = var.venafi_zone
}

output "venafi_template_alias" {
  description = "Venafi issuing template alias"
  value       = var.venafi_template_alias
}

output "venafi_cloud_url" {
  description = "Venafi Control Plane (VCP) URL"
  value       = var.venafi_cloud_url
}

# Certificate Configuration Variables
output "certificate_count_config" {
  description = "Configured number of certificates to create"
  value       = var.certificate_count
}

output "certificate_domain" {
  description = "Domain name for certificates"
  value       = var.certificate_domain
}

output "certificate_algorithm" {
  description = "Certificate algorithm"
  value       = var.certificate_algorithm
}

output "certificate_rsa_bits" {
  description = "RSA key size"
  value       = var.certificate_rsa_bits
}

output "certificate_valid_days" {
  description = "Certificate validity period in days"
  value       = var.certificate_valid_days
}