
data "terraform_remote_state" "vault_core" {
  backend = "local"
  config = {
    path = "../10-vault-core/terraform.tfstate"
  }
}

data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../30-gitlab-kubeadm/terraform.tfstate"
  }
}

