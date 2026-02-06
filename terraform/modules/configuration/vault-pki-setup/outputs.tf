
# Database Services

output "postgres_role_names" {
  description = "Map of Postgres PKI Role Names by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-postgres"].name }
}

output "redis_role_names" {
  description = "Map of Redis PKI Role Names by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-redis"].name }
}

output "minio_role_names" {
  description = "Map of MinIO (S3) PKI Role Names by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-minio"].name }
}

output "postgres_role_domains" {
  description = "Map of allowed domains for Postgres PKI roles by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-postgres"].allowed_domains }
}

output "redis_role_domains" {
  description = "Map of allowed domains for Redis PKI roles by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-redis"].allowed_domains }
}

output "minio_role_domains" {
  description = "Map of allowed domains for MinIO PKI roles by platform"
  value       = { for p in local.platforms : p => vault_pki_secret_backend_role.db_services["${p}-minio"].allowed_domains }
}

# Ingress Services

output "ingress_role_names" {
  description = "Map of Ingress PKI Role Names (key: service identifier, e.g., 'harbor-ingress', 'dev-harbor-ingress')"
  value       = { for k, v in vault_pki_secret_backend_role.ingress_services : k => v.name }
}

output "ingress_role_domains" {
  description = "Map of allowed domains for Ingress PKI roles"
  value       = { for k, v in vault_pki_secret_backend_role.ingress_services : k => v.allowed_domains }
}

# General PKI Info
output "vault_pki_path" {
  description = "The path of the PKI backend"
  value       = var.vault_pki_path
}

output "pki_root_ca_certificate" {
  description = "The Public Certificate of the PKI Root CA"
  value       = vault_pki_secret_backend_root_cert.prod_root_ca.certificate
}
