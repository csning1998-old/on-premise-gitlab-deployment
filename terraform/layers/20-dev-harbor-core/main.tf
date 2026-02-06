
# Call the Identity Module to generate AppRole & Secret ID
module "dev_harbor_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.dev_harbor_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name

  pki_mount_path     = data.terraform_remote_state.vault_core.outputs.pki_configuration.path
  approle_mount_path = data.terraform_remote_state.vault_core.outputs.auth_backend_paths["approle"]
  extra_policy_hcl   = <<EOT
path "secret/data/on-premise-gitlab-deployment/dev-harbor/*" {
  capabilities = ["read"]
}
EOT
}

module "dev_harbor" {
  source = "../../modules/services-docker/harbor"

  topology_config = var.dev_harbor_compute
  infra_config    = var.dev_harbor_infra
  service_domain  = local.service_domain

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

  service_credentials = {
    harbor_admin_password = data.vault_generic_secret.db_vars.data["dev_harbor_admin_password"]
    harbor_pg_db_password = data.vault_generic_secret.db_vars.data["dev_harbor_pg_db_password"]
  }

  vault_agent_config = {
    role_id     = module.dev_harbor_identity.approle_role_id
    secret_id   = module.dev_harbor_identity.approle_secret_id
    ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
    role_name   = local.vault_role_name
    address     = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443"
  }
}
