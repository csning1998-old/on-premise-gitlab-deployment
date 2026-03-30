
# 1. Define Granular Administrative Policy for Production
# Restricts access to business-specific paths (PKI, KV) and admin tasks.
resource "vault_policy" "production_admin" {
  provider = vault.production
  name     = "production-terraform-admin-policy"

  policy = <<EOT
# [1] KV v2 業務機密：精確鎖定於特定專案路徑，並補齊完整生命週期 API
path "secret/data/on-premise-gitlab-deployment/*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "secret/metadata/on-premise-gitlab-deployment/*" {
  capabilities = ["read", "list", "delete"]
}

path "secret/delete/on-premise-gitlab-deployment/*" {
  capabilities = ["update"]
}

path "secret/destroy/on-premise-gitlab-deployment/*" {
  capabilities = ["update"]
}

# [2] PKI 基礎設施：撤銷全域萬用字元，僅允許針對特定 Role 簽發憑證
path "pki/issue/gitlab-service-role" {
  capabilities = ["create", "update"]
}

path "pki/cert/*" {
  capabilities = ["read"]
}

# [3] AppRole 驗證：嚴格禁止修改機制，僅允許讀取專屬的 Role ID
path "auth/approle/role/gitlab-deployment-role/role-id" {
  capabilities = ["read"]
}
EOT
}

# 2. Enable AppRole auth backend on production cluster
resource "vault_auth_backend" "approle" {
  provider = vault.production
  type     = "approle"
  path     = "approle"
}

# 3. Create the Production Terraform Admin Role
resource "vault_approle_auth_backend_role" "terraform_admin" {
  provider       = vault.production
  backend        = vault_auth_backend.approle.path
  role_name      = "production-terraform-admin"
  token_policies = [vault_policy.production_admin.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
}

# 4. Generate the persistent SecretID for downstream layers
resource "vault_approle_auth_backend_role_secret_id" "terraform_admin" {
  provider  = vault.production
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.terraform_admin.role_name
}
