
# Define Policy that allows Harbor apply for certs
resource "vault_policy" "dev_harbor_pki" {
  name = "${var.vault_role_name}-pki-policy"

  policy = <<EOT
path "${var.vault_pki_mount_path}/issue/${var.vault_role_name}" {
  capabilities = ["create", "update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOT
}

# Create AppRole that define the role of Harbor
resource "vault_approle_auth_backend_role" "dev_harbor" {
  backend        = "approle"
  role_name      = var.vault_role_name
  token_policies = ["default", vault_policy.dev_harbor_pki.name]

  token_ttl     = 60 * 60
  token_max_ttl = 60 * 60 * 24
}

resource "vault_pki_secret_backend_role" "dev_harbor_client" {
  backend            = var.vault_pki_mount_path
  name               = "dev-harbor-client-role"
  allowed_domains    = ["dev-harbor", "dev-harbor.iac.local"]
  allow_subdomains   = true
  allow_ip_sans      = true
  allow_any_name     = false
  allow_bare_domains = true
  key_type           = "rsa"
  key_bits           = 2048
  key_usage          = ["DigitalSignature", "KeyAgreement", "KeyEncipherment"]
  ttl                = 60 * 60 * 24
  client_flag        = true
  server_flag        = false
}

# Generate Secret ID for login credentials
resource "vault_approle_auth_backend_role_secret_id" "dev_harbor" {
  backend   = vault_approle_auth_backend_role.dev_harbor.backend
  role_name = vault_approle_auth_backend_role.dev_harbor.role_name
}
