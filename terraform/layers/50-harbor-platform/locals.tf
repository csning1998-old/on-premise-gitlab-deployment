
# Provider Configuration (Restored)
locals {
  kubeconfig   = yamldecode(data.terraform_remote_state.microk8s_provision.outputs.kubeconfig_content)
  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user
}

# for platform-trust-engine module
locals {
  # K8s API Endpoint for Vault Callback
  k8s_api_endpoint = "https://${data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_ip_list[0]}:${var.microk8s_api_port}"

  # Cluster CA from ConfigMap
  k8s_cluster_ca = data.kubernetes_config_map.kube_root_ca.data["ca.crt"]

  # Vault Address
  vault_address  = "https://${data.terraform_remote_state.vault_pki.outputs.vault_ha_virtual_ip}:443"
  vault_ca_cert  = data.terraform_remote_state.vault_pki.outputs.vault_certificates.ca_cert.ca_cert
  vault_pki_path = data.terraform_remote_state.vault_pki.outputs.pki_configuration.path
}

# DNS Configuration
locals {
  dns_hosts = {
    "${data.terraform_remote_state.redis.outputs.harbor_redis_virtual_ip}"       = "redis.harbor.iac.local"
    "${data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip}" = "postgres.harbor.iac.local"
    "${data.terraform_remote_state.minio.outputs.harbor_minio_virtual_ip}"       = "minio.harbor.iac.local"
  }
}
