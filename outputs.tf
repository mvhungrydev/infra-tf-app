# Output values
# Certificate outputs
output "certificate_common_names" {
  description = "Common names of all created certificates"
  value       = venafi_certificate.certificates[*].common_name
}

output "certificate_serial_numbers" {
  description = "Serial numbers of all created certificates"
  value       = venafi_certificate.certificates[*].serial_number
}

output "certificate_thumbprints" {
  description = "Thumbprints of all created certificates"
  value       = venafi_certificate.certificates[*].certificate_thumbprint
}

output "certificate_count" {
  description = "Total number of certificates created"
  value       = length(venafi_certificate.certificates)
}