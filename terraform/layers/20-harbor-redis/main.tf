
# Call the Identity Module to generate AppRole & Secret ID
module "redis_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.harbor_redis_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name

  pki_mount_path     = data.terraform_remote_state.vault_core.outputs.pki_configuration.path
  approle_mount_path = data.terraform_remote_state.vault_core.outputs.auth_backend_paths["approle"]
}

module "redis_harbor" {
  source = "../../modules/service-ha/sentinel-cluster"

  # Topology
  topology_config = var.harbor_redis_compute
  infra_config    = var.harbor_redis_infra
  service_domain  = local.service_domain

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
    redis_requirepass = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    redis_masterauth  = data.vault_generic_secret.db_vars.data["redis_masterauth"]
    redis_vrrp_secret = data.vault_generic_secret.db_vars.data["redis_vrrp_secret"]
  }

  vault_agent_config = {
    role_id     = module.redis_identity.approle_role_id
    secret_id   = module.redis_identity.approle_secret_id
    ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
    role_name   = local.vault_role_name
  }
}
