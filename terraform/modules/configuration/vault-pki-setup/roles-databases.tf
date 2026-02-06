
# Role: Internal Database Services (Postgres, Redis, MinIO)
resource "vault_pki_secret_backend_role" "db_services" {
  for_each = var.database_roles

  backend         = vault_mount.pki_prod.path
  name            = each.value.name
  allowed_domains = each.value.allowed_domains

  allow_subdomains   = true
  allow_ip_sans      = true
  allow_bare_domains = true
  allow_glob_domains = false

  key_usage = ["DigitalSignature", "KeyEncipherment", "KeyAgreement"]

  server_flag = true
  client_flag = true

  max_ttl = 60 * 60 * 24 * 30 # 30 Days
  ttl     = 60 * 60 * 24      # 24 Hours

  allow_any_name    = false
  enforce_hostnames = true
}
