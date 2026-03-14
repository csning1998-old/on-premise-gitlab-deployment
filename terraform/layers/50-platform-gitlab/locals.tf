
# 1. K8s Provider Authentication Context
locals {
  kubeconfig   = yamldecode(base64decode(data.vault_generic_secret.kubeconfig.data["content_b64"]))
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  api_server_connection = {
    host               = local.cluster_info.server
    ca_cert            = base64decode(local.cluster_info["certificate-authority-data"])
    client_certificate = base64decode(local.user_info["client-certificate-data"])
    client_key         = base64decode(local.user_info["client-key-data"])
  }
}

# 2. Addons & Trust Engine Context
locals {
  # SSoT Discovery
  ssot_gitlab = data.terraform_remote_state.metadata.outputs.global_service_structure["gitlab"]
  ssot_vault  = data.terraform_remote_state.metadata.outputs.global_service_structure["vault"]

  # FQDNs
  gitlab_fqdn = local.ssot_gitlab.components["frontend"].role.dns_san[0]
  vault_fqdn  = local.ssot_vault.components["raft"].role.dns_san[0]

  # Harbor Bootstrapper (Registry Redirection)
  harbor_registry   = data.terraform_remote_state.metadata.outputs.global_service_structure["harbor-bootstrapper"].components.frontend.role.dns_san[0]
  harbor_image_path = "quay-proxy"

  # K8s API Endpoint for Vault Callback (Standardized)
  api_port     = local.ssot_gitlab.meta.ports["api-server"].frontend_port
  api_endpoint = "https://${data.terraform_remote_state.kubeadm_provision.outputs.service_vip}:${local.api_port}"

  # Cluster CA from ConfigMap
  cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Connection (Standardized)
  vault_api_port    = local.ssot_vault.meta.ports["api"].frontend_port
  vault_address     = "https://${data.terraform_remote_state.vault_pki.outputs.vault_service_vip}:${local.vault_api_port}"
  vault_ca_cert     = data.terraform_remote_state.vault_pki.outputs.bootstrap_ca.content
  vault_pki_path    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.path
  vault_role_name   = data.terraform_remote_state.vault_pki.outputs.pki_configuration.component_roles["gitlab-frontend"].name
  vault_auth_path   = data.terraform_remote_state.vault_pki.outputs.auth_backend_paths["kubernetes"]
  vault_policy_name = "${local.vault_role_name}-pki-policy"
}

# 3. DNS Configuration (Standardized)
locals {
  dns_hosts = {
    "${data.terraform_remote_state.kubeadm_provision.outputs.service_vip}" = local.gitlab_fqdn
    "${data.terraform_remote_state.vault_pki.outputs.vault_service_vip}"   = local.vault_fqdn

    # Dependency Roles
    "${data.terraform_remote_state.redis.outputs.service_vip}"    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-redis-dep"].allowed_domains[0]
    "${data.terraform_remote_state.postgres.outputs.service_vip}" = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-postgres-dep"].allowed_domains[0]
    "${data.terraform_remote_state.minio.outputs.service_vip}"    = data.terraform_remote_state.vault_pki.outputs.pki_configuration.dependency_roles["gitlab-minio-dep"].allowed_domains[0]
  }
}
