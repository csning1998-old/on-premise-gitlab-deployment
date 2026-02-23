
module "kubeadm_gitlab" {
  source = "../../middleware/ha-service-kvm/kubeadm-cluster"

  # Identity & Service Definitions
  cluster_name   = local.svc_cluster_name
  service_vip    = local.net_service_vip
  service_domain = local.svc_fqdn

  # Topology (Compute & Storage)
  topology_cluster = local.topology_cluster

  # Network Infrastructure with Dual-Tier
  network_bindings   = local.network_bindings
  network_parameters = local.network_parameters

  # Credentials & Security
  credentials_system = local.sec_system_creds

  # Ansible Configuration
  ansible_files = var.ansible_files

  # Layer 00 Artifacts (Root CA) for Ansible trust store
  security_pki_bundle = local.pki_global_ca

  # Vault Agent Identity Injection
  credentials_vault_agent = merge(
    local.sec_vault_agent_identity,
    {
      secret_id = vault_approle_auth_backend_role_secret_id.kubeadm_agent.secret_id
    }
  )
}
