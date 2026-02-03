

# Kubeadm Cluster State

data "terraform_remote_state" "gitlab_cluster" {
  backend = "local"
  config = {
    path = "../30-gitlab-kubeadm/terraform.tfstate"
  }
}

data "terraform_remote_state" "gitlab_platform" {
  backend = "local"
  config = {
    path = "../40-gitlab-platform/terraform.tfstate"
  }
}

# HashiCorp Vault State
data "terraform_remote_state" "vault_core" {
  backend = "local"
  config = {
    path = "../10-vault-core/terraform.tfstate"
  }
}

# Infrastructure VIPs
data "terraform_remote_state" "redis" {
  backend = "local"
  config = {
    path = "../20-gitlab-redis/terraform.tfstate"
  }
}

data "terraform_remote_state" "postgres" {
  backend = "local"
  config = {
    path = "../20-gitlab-postgres/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio" {
  backend = "local"
  config = {
    path = "../20-gitlab-minio/terraform.tfstate"
  }
}

data "vault_generic_secret" "variables" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

# Vault Secrets for reading database and service passwords.
data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/databases"
}

data "vault_generic_secret" "gitlab_vars" {
  path = "secret/on-premise-gitlab-deployment/gitlab/app"
}

# path: secret/on-premise-gitlab-deployment/gitlab/s3_credentials/[bucket_name]

data "vault_generic_secret" "s3_artifacts" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-artifacts"
}

data "vault_generic_secret" "s3_lfs" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-lfs"
}

data "vault_generic_secret" "s3_uploads" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-uploads"
}

data "vault_generic_secret" "s3_packages" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-packages"
}

data "vault_generic_secret" "s3_terraform_state" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-terraform-state"
}

data "vault_generic_secret" "s3_backups" {
  path = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials/gitlab-backups"
}
