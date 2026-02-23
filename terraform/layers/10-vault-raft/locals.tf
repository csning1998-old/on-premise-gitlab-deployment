
# State Object
locals {
  state = {
    topology = data.terraform_remote_state.topology.outputs
    network  = data.terraform_remote_state.network.outputs
  }
}

# Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_meta         = local.state.topology.service_structure[local.svc_name]
  svc_fqdn         = local.state.topology.domain_suffix
  svc_cluster_name = "${local.svc_meta.meta.name}-${local.svc_meta.meta.project_code}"
}

# Network Context
locals {
  net_vault       = local.state.network.network_service_topology[local.svc_name]
  net_service_vip = local.net_vault.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "vault" = {
      nat_net_name         = local.net_vault.network.nat.name
      nat_bridge_name      = local.net_vault.network.nat.bridge_name
      hostonly_net_name    = local.net_vault.network.hostonly.name
      hostonly_bridge_name = local.net_vault.network.hostonly.bridge_name
    }
  }

  # Network Parameters: L3 Routing & Configuration
  network_parameters = {
    "vault" = {
      network = {
        nat = {
          gateway = local.net_vault.network.nat.gateway
          cidrv4  = local.net_vault.network.nat.cidr
          dhcp    = local.net_vault.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_vault.network.hostonly.gateway
          cidrv4  = local.net_vault.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_vault.network.hostonly.cidr
    }
  }
}

# Security Context
locals {
  pki_global_ca = try(local.state.topology.vault_pki, null) # PKI Artifacts

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
  storage_pool_name = "iac-${local.svc_cluster_name}"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.vault_config
  }
}
