
output "tls_source_dir" {
  description = "The directory where certificates were saved."
  value       = var.output_dir
}

output "ca_cert_file" {
  description = "Absolute path to the generated CA certificate file."
  value       = "${var.output_dir}/vault-ca.crt"
}
