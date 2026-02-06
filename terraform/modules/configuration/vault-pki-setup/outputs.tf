
# Database Services Output
output "database_roles" {
  description = "Map of all created Database PKI roles containing name and allowed_domains"
  value = {
    for key, role in vault_pki_secret_backend_role.db_services : key => {
      name            = role.name
      allowed_domains = role.allowed_domains
    }
  }
}

# Ingress Services Output
output "ingress_roles" {
  description = "Map of all created Ingress PKI roles containing name and allowed_domains"
  value = {
    for key, role in vault_pki_secret_backend_role.ingress_services : key => {
      name            = role.name
      allowed_domains = role.allowed_domains
    }
  }
}

# General PKI Info
output "vault_pki_path" {
  description = "The path of the PKI backend"
  value       = vault_mount.pki_prod.path
}

output "pki_root_ca_certificate" {
  description = "The Public Certificate of the PKI Root CA"
  value       = vault_pki_secret_backend_root_cert.prod_root_ca.certificate
}

output "auth_backend_paths" {
  description = "Map of enabled Auth Backend paths"
  value       = { for k, v in vault_auth_backend.this : k => v.path }
}
