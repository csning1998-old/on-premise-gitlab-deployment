
resource "random_password" "gitlab_internal" {
  for_each = toset(["rails-secret", "shell-secret", "gitaly-secret", "root-password"])
  length   = 32
  special  = false
}

resource "vault_kv_secret_v2" "gitlab_internal_keys" {
  provider = vault.production
  mount    = "secret"
  name     = "on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key    = random_password.gitlab_internal["rails-secret"].result
    gitlab_shell_secret = random_password.gitlab_internal["shell-secret"].result
    gitaly_token        = random_password.gitlab_internal["gitaly-secret"].result
    root_password       = random_password.gitlab_internal["root-password"].result
  })
}

# 3. K8s Infrastructure Secrets (Re-added to fix undeclared resource error)
resource "kubernetes_secret" "gitlab_postgres_tls" {
  metadata {
    name      = "gitlab-postgres-tls"
    namespace = var.gitlab_helm_config.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = base64decode(jsondecode(data.vault_kv_secret_v2.gitlab_db.data_json)["tls"]["crt"])
    "tls.key" = base64decode(jsondecode(data.vault_kv_secret_v2.gitlab_db.data_json)["tls"]["key"])
    "ca.crt"  = base64decode(jsondecode(data.vault_kv_secret_v2.gitlab_db.data_json)["tls"]["ca"])
  }
}
