
# Rails Secret Key Base for Session Encryption
resource "random_password" "rails_secret_key" {
  length  = 64
  special = false
}

# GitLab Shell Secret for GitLab Shell and Rails API communication
resource "random_password" "shell_secret" {
  length  = 64
  special = false
}

# Gitaly Token for Gitaly authentication
resource "random_password" "gitaly_token" {
  length  = 64
  special = false
}

# Initial Root Password for login
resource "random_password" "root_password" {
  length  = 24
  special = false
}

# Write generated password back to Vault for record-keeping and application reference
resource "vault_generic_secret" "gitlab_internal_keys" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app/internal"

  data_json = jsonencode({
    rails_secret_key      = random_password.rails_secret_key.result
    gitlab_shell_secret   = random_password.shell_secret.result
    gitaly_token          = random_password.gitaly_token.result
    initial_root_password = random_password.root_password.result
  })
}

# Inject generated password to Kubernetes Secrets

resource "kubernetes_secret" "gitlab_rails_secret" {
  metadata {
    name      = "gitlab-rails-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
  data = {
    "secret" = random_password.rails_secret_key.result
  }
}

resource "kubernetes_secret" "gitlab_shell_secret" {
  metadata {
    name      = "gitlab-shell-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
  data = {
    "secret" = random_password.shell_secret.result
  }
}

resource "kubernetes_secret" "gitlab_gitaly_secret" {
  metadata {
    name      = "gitlab-gitaly-secret"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
  data = {
    "token" = random_password.gitaly_token.result
  }
}

resource "kubernetes_secret" "gitlab_root_password" {
  metadata {
    name      = "gitlab-root-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
  data = {
    "password" = random_password.root_password.result
  }
}

# Inject Vault Root CA into Kubernetes for GitLab to trust Redis/Postgres/MinIO
resource "kubernetes_secret" "gitlab_custom_ca" {
  metadata {
    name      = "gitlab-custom-ca"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    "vault-api-ca.crt"    = data.terraform_remote_state.vault_core.outputs.vault_ca_cert
    "internal-pki-ca.crt" = data.terraform_remote_state.vault_core.outputs.internal_pki_ca_cert
  }
}
