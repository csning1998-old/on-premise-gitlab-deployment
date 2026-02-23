
# Call the Identity Module to generate AppRole & Secret ID

module "minio_gitlab" {
  source = "../../middleware/ha-service-kvm/minio-distributed-cluster"

  # Identity & Service Definitions
  cluster_name   = local.svc_cluster_name
  service_vip    = local.net_service_vip
  service_domain = local.svc_minio_fqdn
  service_ports  = local.net_minio.lb_config.ports

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure with Dual-Tier
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # Credentials & Security
  credentials_system = local.sec_system_creds
  credentials_db     = local.sec_db_creds

  # Layer 00 Artifacts (Root CA) for Ansible trust store
  security_pki_bundle = local.pki_global_ca

  # Vault Agent Identity Injection
  credentials_vault_agent = merge(
    local.sec_vault_agent_identity,
    {
      secret_id = vault_approle_auth_backend_role_secret_id.patroni_agent.secret_id
    }
  )
}

# This timer is to wait for MinIO Cluster to initialize the storage.
resource "time_sleep" "wait_for_minio_storage" {
  depends_on      = [module.minio_gitlab]
  create_duration = "30s"
}

module "minio_gitlab_config" {
  source     = "../../modules/configuration/minio-bucket-setup"
  depends_on = [time_sleep.wait_for_minio_storage]

  minio_tenants            = var.gitlab_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/gitlab/s3_credentials"
  minio_server_url         = "https://${local.net_service_vip}:${local.net_minio.lb_config.ports["api"].frontend_port}"
}
