
# Microk8s Configuration
locals {
  kubeconfig_raw = data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user
  issuer_name  = data.terraform_remote_state.harbor_platform.outputs.platform_issuer_name
  issuer_kind  = data.terraform_remote_state.harbor_platform.outputs.platform_issuer_kind
}

# Vault Generic Secrets
locals {
  vm_username      = data.vault_generic_secret.variables.data["vm_username"]
  private_key_path = data.vault_generic_secret.variables.data["ssh_private_key_path"]

  minio_access_key = data.vault_generic_secret.s3_credentials.data["access_key"]
  minio_secret_key = data.vault_generic_secret.s3_credentials.data["secret_key"]

  harbor_pg_password    = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
  redis_password        = data.vault_generic_secret.db_vars.data["redis_requirepass"]
  harbor_admin_password = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]
}

# External Service Address. The format should abide by the Helm Chart requirement.
locals {
  postgres_address = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-postgres"].allowed_domains[0]
  redis_address    = "${data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-redis"].allowed_domains[0]}:6379"
  minio_address    = "https://${data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["harbor-minio"].allowed_domains[0]}:9000"
}
