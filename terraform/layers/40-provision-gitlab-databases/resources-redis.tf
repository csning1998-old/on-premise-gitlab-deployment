
# Redis Password Generation & Vault Storage
# This resource belongs to the Database Provisioning layer (Layer 40)
# to ensure it is available before the application (Layer 60) starts.

resource "random_password" "gitlab_redis" {
  length  = 32
  special = false
}

resource "vault_generic_secret" "gitlab_redis_keys" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/gitlab/app/redis"

  data_json = jsonencode({
    password = random_password.gitlab_redis.result
  })
}
