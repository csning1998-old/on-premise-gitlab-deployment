
# Define Policy that allows Postgres apply for certs
resource "vault_policy" "postgres_pki" {
  name = "postgres-pki-policy"

  policy = <<EOT
path "pki/prod/issue/postgres-role" {
  capabilities = ["create", "update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# Create AppRole that define the role of Postgres
resource "vault_approle_auth_backend_role" "postgres" {
  backend        = "approle"
  role_name      = var.vault_role_name
  token_policies = ["default", vault_policy.postgres_pki.name]

  token_ttl     = 3600
  token_max_ttl = 86400
}

resource "vault_pki_secret_backend_role" "postgres_client" {
  backend          = var.vault_pki_mount_path
  name             = "postgres-client-role"
  ttl              = 86400
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 2048
  allowed_domains  = ["harbor", "gitlab", "client.iac.local"]
  allow_subdomains = true
  allow_any_name   = false
  client_flag      = true
  server_flag      = false
}

# Generate Secret ID for login credentials
resource "vault_approle_auth_backend_role_secret_id" "postgres" {
  backend   = vault_approle_auth_backend_role.postgres.backend
  role_name = vault_approle_auth_backend_role.postgres.role_name
}
