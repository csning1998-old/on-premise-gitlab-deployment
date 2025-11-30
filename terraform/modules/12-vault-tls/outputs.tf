
output "tls_source_dir" {
  value       = abspath("${path.module}/tls")
  description = "The absolute path of the directory containing generated certificates."
}

output "ca_cert_file" {
  value       = abspath(local_file.vault_ca.filename)
  description = "Absolute path to the CA certificate file."
}
