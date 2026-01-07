
# For Vault Agent to apply for certs
# Role: Postgres
resource "vault_pki_secret_backend_role" "postgres" {
  backend = vault_mount.pki_prod.path
  name    = "postgres-role"

  allowed_domains = local.postgres_domains

  allow_subdomains   = true
  allow_glob_domains = true
  allow_ip_sans      = true

  key_usage = [
    "DigitalSignature",
    "KeyAgreement",
    "KeyEncipherment"
  ]

  server_flag = true
  client_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}

# Role: Redis
resource "vault_pki_secret_backend_role" "redis" {
  backend = vault_mount.pki_prod.path
  name    = "redis-role"

  allowed_domains  = local.redis_domains
  allow_subdomains = true
  allow_ip_sans    = true

  key_usage   = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]
  client_flag = true
  server_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours
}

# Role: MinIO
resource "vault_pki_secret_backend_role" "minio" {
  backend = vault_mount.pki_prod.path
  name    = "minio-role"

  allowed_domains  = local.minio_domains
  allow_subdomains = true
  allow_ip_sans    = true

  key_usage   = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]
  client_flag = true
  server_flag = true

  max_ttl = 2592000 # 30 Days
  ttl     = 86400   # 24 Hours
}

