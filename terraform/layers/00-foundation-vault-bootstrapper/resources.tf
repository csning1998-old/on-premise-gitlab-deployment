
# Define Terraform Administrative Policy
resource "vault_policy" "terraform_admin" {
  name   = "terraform-admin-policy"
  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

# Enable AppRole auth backend
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# Create the Terraform AppRole
resource "vault_approle_auth_backend_role" "terraform_admin" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform-admin-role"
  token_policies = [vault_policy.terraform_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

resource "vault_approle_auth_backend_role_secret_id" "terraform_admin" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.terraform_admin.role_name
}
