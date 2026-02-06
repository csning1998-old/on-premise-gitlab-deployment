
module "postgres_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.gitlab_postgres_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name

  pki_mount_path     = data.terraform_remote_state.vault_core.outputs.pki_configuration.path
  approle_mount_path = data.terraform_remote_state.vault_core.outputs.auth_backend_paths["approle"]
}

module "postgres_gitlab" {
  source = "../../modules/service-ha/patroni-cluster"

  # Topology
  topology_config = var.gitlab_postgres_compute
  infra_config    = var.gitlab_postgres_infra
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
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  vault_agent_config = {
    role_id     = module.postgres_identity.approle_role_id
    secret_id   = module.postgres_identity.approle_secret_id
    ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
    role_name   = local.vault_role_name
  }
}
