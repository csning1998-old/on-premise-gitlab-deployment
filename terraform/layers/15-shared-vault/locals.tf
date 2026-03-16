
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs      # Source from `00-foundation-metadata`
    volume   = data.terraform_remote_state.volume.outputs        # Source from `05-foundation-volume`
    network  = data.terraform_remote_state.load_balancer.outputs # Source from `10-shared-load-balancer`
  }
}

# Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_raft_comp    = local.state.metadata.global_service_structure[local.svc_name].components["raft"]
  svc_identity     = local.svc_raft_comp.identity
  svc_fqdn         = local.svc_raft_comp.role.dns_san[0]
  svc_cluster_name = local.svc_identity.cluster_name
}

# Network Context
locals {
  net_vault_infra = local.state.network.infrastructure_map[local.state.metadata.global_service_structure[local.svc_name].network.segment_key]
  net_service_vip = local.net_vault_infra.lb_config.vip

  # Single map of raw infrastructures for KVM
  network_infrastructure_map = {
    vault = local.net_vault_infra
  }
}

# Security Context
locals {
  pki_global_ca = local.state.metadata.global_vault_pki # PKI Artifacts

  # System Level Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
}

# Topology Component Construction
locals {
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_cluster = {
    components        = var.vault_config
    storage_pool_name = local.storage_pool_name
  }

  node_identities = {
    "vault" = local.svc_identity
  }
}

# Ansible Configuration (Dynamic Inventory)
locals {
  ansible_template_vars = {
    vault_vip = local.net_service_vip
  }

  ansible_extra_vars = merge(
    {
      ansible_user = local.sec_system_creds.username
    },
    local.pki_global_ca != null && length(keys(local.pki_global_ca)) > 0 ? {
      vault_server_cert = local.pki_global_ca.server_cert
      vault_server_key  = local.pki_global_ca.server_key
      vault_ca_cert     = local.pki_global_ca.ca_cert
    } : {}
  )
}
