
module "microk8s_harbor" {
  source = "../../middleware/ha-service-kvm/microk8s-cluster"

  # Core Identifier & Topology
  cluster_name     = local.svc_cluster_name
  topology_cluster = local.topology_cluster
  service_vip      = local.net_service_vip

  # Network & Infrastructure
  network_parameters = local.network_parameters
  network_bindings   = local.network_bindings

  # Security & Credentials
  credentials_system = local.sec_system_creds
  credentials_vault_agent = merge(
    local.sec_vault_agent_identity,
    {
      secret_id = vault_approle_auth_backend_role_secret_id.microk8s_agent.secret_id
    }
  )
  security_pki_bundle = local.pki_global_ca
  ansible_files       = var.ansible_files
}
