
# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "this" {
  backend   = data.terraform_remote_state.vault_pki.outputs.workload_identities_dependencies["${var.service_catalog_name}-postgres-dep"].auth_path
  role_name = data.terraform_remote_state.vault_pki.outputs.workload_identities_dependencies["${var.service_catalog_name}-postgres-dep"].role_name
}

module "build_gitlab_postgres_cluster" {
  source = "../../modules/service-ha/patroni-cluster"

  # Topology
  topology_config  = local.cluster_components
  cluster_name     = local.cluster_name
  service_vip      = local.service_vip
  service_domain   = local.service_domain
  vm_credentials   = local.vm_credentials
  db_credentials   = local.db_credentials
  network_config   = local.network_config
  network_identity = local.network_identity
  pki_artifacts    = local.vault_pki
  vault_agent_config = merge(local.vault_agent_config, {
    secret_id = vault_approle_auth_backend_role_secret_id.this.secret_id
  })
}
