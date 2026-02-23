
# State Object
locals {
  state = {
    topology  = data.terraform_remote_state.topology.outputs
    network   = data.terraform_remote_state.network.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
  }
}

# Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_meta         = local.state.topology.service_structure[local.svc_name]
  svc_fqdn         = local.state.topology.domain_suffix
  svc_cluster_name = "${local.svc_meta.meta.name}-${local.svc_meta.meta.project_code}"

  kubeadm_comp_meta = local.svc_meta.components["frontend"]
  svc_kubeadm_fqdn  = try(local.kubeadm_comp_meta.dns_san[0], local.svc_fqdn)
}

# Network Context
locals {
  net_kubeadm     = local.state.network.network_service_topology[local.svc_name]
  net_service_vip = local.net_kubeadm.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "default" = {
      nat_net_name         = local.net_kubeadm.network.nat.name
      nat_bridge_name      = local.net_kubeadm.network.nat.bridge_name
      hostonly_net_name    = local.net_kubeadm.network.hostonly.name
      hostonly_bridge_name = local.net_kubeadm.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "default" = {
      network = {
        nat = {
          gateway = local.net_kubeadm.network.nat.gateway
          cidrv4  = local.net_kubeadm.network.nat.cidr
          dhcp    = local.net_kubeadm.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_kubeadm.network.hostonly.gateway
          cidrv4  = local.net_kubeadm.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_kubeadm.network.hostonly.cidr
    }
  }
}

# Security & App Context (sec_ / sys_ / pki_)
locals {
  sys_vault_addr   = "https://${local.state.vault_sys.service_vip}:443"
  pki_global_ca    = try(local.state.topology.gitlab_kubeadm_pki, null)
  pki_vault_ca_b64 = local.state.topology.vault_pki.ca_cert

  # System Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Vault Agent Identity Prep
  sec_vault_identity_key = "${local.svc_name}-frontend"

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = try(local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_id, "")
    role_name     = try(local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_identity_key].name, "")
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_kubeadm_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = "iac-${local.svc_cluster_name}-gitlab-kubeadm"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_kubeadm_config
  }
}

# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "kubeadm_agent" {
  backend   = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].auth_path
  role_name = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-40-gitlab-kubeadm"
    "timestamp" = timestamp()
  })
}
