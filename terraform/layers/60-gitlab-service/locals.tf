
# Kubeadm Configuration & Auth Object
locals {
  kubeconfig_raw = data.terraform_remote_state.kubeadm_provision.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  # Encapsulate K8s Auth Object for Provider Usage (Standardized with Harbor)
  k8s_provider_auth = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  }

  # Get Issuer Information from Layer 50 (Trust Engine Contract)
  issuer_name = data.terraform_remote_state.gitlab_platform.outputs.trust_context.issuer_name
  issuer_kind = data.terraform_remote_state.gitlab_platform.outputs.trust_context.issuer_kind
}

# Vault Generic Secrets
locals {
  vm_username      = data.vault_generic_secret.variables.data["vm_username"]
  private_key_path = data.vault_generic_secret.variables.data["ssh_private_key_path"]

  minio_access_key = data.vault_generic_secret.s3_credentials["gitlab-artifacts"].data["access_key"]
  minio_secret_key = data.vault_generic_secret.s3_credentials["gitlab-artifacts"].data["secret_key"]

  postgres_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
  redis_password    = data.vault_generic_secret.db_vars.data["redis_requirepass"]

  initial_root_password = data.vault_generic_secret.app_vars.data["initial_root_password"]
}

# External Service Address & Ports
locals {
  postgres_rw_port = data.terraform_remote_state.postgres.outputs.gitlab_postgres_haproxy_rw_port
  redis_port       = data.terraform_remote_state.redis.outputs.gitlab_redis_haproxy_stats_port
  minio_port       = data.terraform_remote_state.minio.outputs.gitlab_minio_haproxy_ports.backend_port_api

  postgres_vip = data.terraform_remote_state.postgres.outputs.gitlab_postgres_virtual_ip
  redis_vip    = data.terraform_remote_state.redis.outputs.gitlab_redis_virtual_ip
  minio_vip    = data.terraform_remote_state.minio.outputs.gitlab_minio_virtual_ip
}

# External Service Address. The format should abide by the Helm Chart requirement.
locals {
  gitlab_hostname  = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["gitlab-frontend"].allowed_domains[0]
  postgres_address = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-postgres"].allowed_domains[0]
  redis_address    = "${data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-redis"].allowed_domains[0]}:${local.redis_port}"
  minio_address    = "https://${data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-minio"].allowed_domains[0]}:${local.minio_port}"
}

locals {
  ca_bundle_config = {
    name        = "gitlab-ca-bundle" # K8s Secret Name
    secret_name = "gitlab-ca-bundle" # Helm Chart Reference Name

    content = join("\n", [
      data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert,
      data.http.vault_pki_ca.response_body
    ])
  }
}

locals {
  s3_endpoint = data.vault_generic_secret.s3_artifacts.data["endpoint"]
  s3_region   = "us-east-1"
  s3_bucket_names = toset([
    "gitlab-artifacts",
    "gitlab-lfs",
    "gitlab-uploads",
    "gitlab-packages",
    "gitlab-terraform-state",
    "gitlab-backups"
  ])
}

locals {
  gitlab_secrets = {
    "rails-secret"  = { length = 64, special = false, key = "secret" }
    "shell-secret"  = { length = 64, special = false, key = "secret" }
    "gitaly-secret" = { length = 64, special = false, key = "token" }
    "root-password" = { length = 24, special = false, key = "secret" }
  }
}
