
data "terraform_remote_state" "metadata" {
  backend = "local"
  config = {
    path = "${path.root}/../00-foundation-metadata/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "local"
  config = {
    path = "${path.root}/../10-shared-load-balancer/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_sys" {
  backend = "local"
  config = {
    path = "${path.root}/../15-shared-vault/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_prod_bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../16-security-vault-approle/terraform.tfstate"
  }
}

data "terraform_remote_state" "vault_pki" {
  backend = "local"
  config = {
    path = "${path.root}/../20-security-pki/terraform.tfstate"
  }
}

data "terraform_remote_state" "minio_infra" {
  backend = "local"
  config = {
    path = "${path.module}/../30-infra-gitlab-minio/terraform.tfstate"
  }
}

data "terraform_remote_state" "postgres" {
  backend = "local"
  config = {
    path = "../30-infra-gitlab-postgres/terraform.tfstate"
  }
}

data "vault_generic_secret" "db_vars" {
  provider = vault.production
  path     = "secret/on-premise-gitlab-deployment/gitlab/databases"
}
