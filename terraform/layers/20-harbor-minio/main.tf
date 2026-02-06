
module "minio_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.harbor_minio_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name

  pki_mount_path     = data.terraform_remote_state.vault_core.outputs.pki_configuration.path
  approle_mount_path = data.terraform_remote_state.vault_core.outputs.auth_backend_paths["approle"]
}

module "minio_harbor" {
  source = "../../modules/service-ha/minio-distributed-cluster"

  topology_config = merge(
    var.harbor_minio_compute,
    {
      cluster_identity = merge(
        var.harbor_minio_compute.cluster_identity,
        {
          cluster_name = local.cluster_name
        }
      )
    }
  )
  infra_config   = var.harbor_minio_infra
  service_domain = local.service_domain

  # Network Identity
  network_identity = {
    nat_net_name         = local.nat_net_name
    nat_bridge_name      = local.nat_bridge_name
    hostonly_net_name    = local.hostonly_net_name
    hostonly_bridge_name = local.hostonly_bridge_name
    storage_pool_name    = local.storage_pool_name
  }

  # Credentials Injection
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  db_credentials = {
    minio_root_user     = data.vault_generic_secret.db_vars.data["minio_root_user"]
    minio_root_password = data.vault_generic_secret.db_vars.data["minio_root_password"]
    minio_vrrp_secret   = data.vault_generic_secret.db_vars.data["minio_vrrp_secret"]
  }

  vault_agent_config = {
    role_id     = module.minio_identity.approle_role_id
    secret_id   = module.minio_identity.approle_secret_id
    ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
    role_name   = local.vault_role_name
  }
}

# This timer is to wait for MinIO Cluster to initialize the storage.
resource "time_sleep" "wait_for_minio_storage" {
  depends_on      = [module.minio_harbor]
  create_duration = "30s"
}

module "minio_harbor_system_config" {
  source     = "../../modules/configuration/minio-bucket-setup"
  depends_on = [time_sleep.wait_for_minio_storage]

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = "https://${var.harbor_minio_compute.haproxy_config.virtual_ip}:9000"
}
