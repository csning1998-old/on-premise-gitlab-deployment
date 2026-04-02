
# Redis Password Generation & Vault Storage
# This resource belongs to the Database Provisioning layer (Layer 40)
# to ensure it is available before the application (Layer 60) starts.

resource "random_password" "gitlab_redis" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "gitlab_redis_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    password = data.vault_kv_secret_v2.db_vars.data["redis_requirepass"]
  })
}
