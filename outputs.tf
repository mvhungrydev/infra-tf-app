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

# EC2 vSatellite Outputs
output "vsatellite_instance_id" {
  description = "ID of the vSatellite EC2 instance"
  value       = aws_instance.vsatellite.id
}

output "vsatellite_private_ip" {
  description = "Private IP address of the vSatellite instance"
  value       = aws_instance.vsatellite.private_ip
}

output "vsatellite_subnet_id" {
  description = "Subnet ID where vSatellite is deployed"
  value       = aws_instance.vsatellite.subnet_id
}

output "vsatellite_vpc_id" {
  description = "VPC ID where vSatellite is deployed"
  value       = data.aws_vpc.infra_tf.id
}

output "vsatellite_ssh_command" {
  description = "SSH command to connect to vSatellite instance using traditional SSH"
  value       = var.key_pair_name != "" ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.vsatellite.private_ip}" : "No SSH key pair configured - use AWS Instance Connect instead"
}

output "vsatellite_instance_connect_command" {
  description = "AWS Instance Connect command to SSH to vSatellite"
  value       = "aws ec2-instance-connect ssh --instance-id ${aws_instance.vsatellite.id} --os-user ec2-user"
}

output "vsatellite_instance_connect_endpoint" {
  description = "AWS Instance Connect Endpoint command (if available in your VPC)"
  value       = "aws ec2-instance-connect ssh --instance-id ${aws_instance.vsatellite.id} --os-user ec2-user --instance-connect-endpoint-id <your-ice-endpoint-id>"
}

output "vsatellite_web_url" {
  description = "URL to access vSatellite web interface (after installation, from within VPC)"
  value       = "https://${aws_instance.vsatellite.private_ip}"
}

output "vsatellite_security_group_id" {
  description = "Security Group ID for vSatellite instance"
  value       = data.aws_security_group.vsatellite.id
}

output "vsatellite_security_group_name" {
  description = "Security Group name for vSatellite instance"
  value       = data.aws_security_group.vsatellite.name
}

# Infrastructure Discovery Outputs
output "discovered_vpc_cidr" {
  description = "CIDR block of the discovered VPC"
  value       = data.aws_vpc.infra_tf.cidr_block
}

output "discovered_vpc_name" {
  description = "Name tag of the discovered VPC"
  value       = data.aws_vpc.infra_tf.tags.Name
}

output "available_private_subnets" {
  description = "List of all discovered private subnet IDs"
  value       = local.private_subnet_ids
}

# Quick Access Summary
output "quick_access_summary" {
  description = "Quick reference for accessing the vSatellite instance"
  value = {
    instance_id      = aws_instance.vsatellite.id
    private_ip       = aws_instance.vsatellite.private_ip
    web_interface    = "https://${aws_instance.vsatellite.private_ip}"
    ssh_via_connect  = "aws ec2-instance-connect ssh --instance-id ${aws_instance.vsatellite.id} --os-user ec2-user"
    ssh_traditional  = var.key_pair_name != "" ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.vsatellite.private_ip}" : "No SSH key configured"
  }
}