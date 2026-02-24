
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
  svc_name  = var.service_catalog_name
  comp_name = var.bootstrap_harbor_config.role

  # Following exact HA pattern from Topology
  svc_identity_key = "${local.svc_name}-${local.comp_name}"
  svc_identity     = local.state.topology.identity_map[local.svc_identity_key]

  # Single Node explicitly defined
  # HA Node Suffix pattern: cluster_name-comp_name-00
  svc_cluster_name    = local.svc_identity.cluster_name
  svc_node_suffix     = "00"
  svc_node_name       = "${local.svc_cluster_name}-${local.comp_name}-${local.svc_node_suffix}"
  svc_dev_harbor_fqdn = local.state.topology.pki_map[local.svc_identity_key].dns_san[0]
}

# Network Context (Exact HA Injection Mapping)
locals {
  net_config  = local.state.network.infrastructure_map[local.svc_name]
  net_node_ip = cidrhost(local.net_config.network.hostonly.cidr, var.bootstrap_harbor_config.node.ip_suffix)

  network_bindings = {
    "default" = {
      nat_net_name         = local.net_config.network.nat.name
      nat_bridge_name      = local.net_config.network.nat.bridge_name
      hostonly_net_name    = local.net_config.network.hostonly.name
      hostonly_bridge_name = local.net_config.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "default" = {
      network = {
        nat = {
          gateway = local.net_config.network.nat.gateway
          cidrv4  = local.net_config.network.nat.cidr
          dhcp    = local.net_config.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_config.network.hostonly.gateway
          cidrv4  = local.net_config.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_config.network.hostonly.cidr
    }
  }
}

# Security & App Context
locals {
  sys_vault_addr   = "https://${local.state.vault_sys.service_vip}:443"
  pki_vault_ca_b64 = local.state.topology.vault_pki.ca_cert

  sec_system_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  sec_app_creds = {
    harbor_admin_password = data.vault_generic_secret.db_vars.data["dev_harbor_admin_password"]
    harbor_pg_db_password = data.vault_generic_secret.db_vars.data["dev_harbor_pg_db_password"]
  }

  sec_vault_identity_key = local.svc_identity_key
  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = local.state.vault_pki.workload_identities_components[local.sec_vault_identity_key].role_id
    role_name     = local.state.vault_pki.pki_configuration.component_roles[local.sec_vault_identity_key].name
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_dev_harbor_fqdn
  }
}

# Topology Component Construction (HA Standalone Object)
locals {
  topology_node = {
    storage_pool_name = local.svc_identity.storage_pool_name

    base_image_path = var.bootstrap_harbor_config.base_image_path
    role            = local.comp_name
    network_tier    = var.bootstrap_harbor_config.network_tier

    ip_suffix  = var.bootstrap_harbor_config.node.ip_suffix
    vcpu       = var.bootstrap_harbor_config.node.vcpu
    ram        = var.bootstrap_harbor_config.node.ram
    data_disks = var.bootstrap_harbor_config.node.data_disks
  }
}

# Ansible Configuration Rendering
locals {
  ansible_inventory_content = templatefile("${path.module}/../../templates/${var.ansible_files.inventory_template_file}", {
    service_name = local.svc_name

    dev_harbor_nodes = {
      "${local.svc_node_name}" = { ip = local.net_node_ip }
    }

    cluster_identity = {
      name        = local.svc_node_name
      domain      = local.state.topology.domain_suffix
      common_name = local.sec_vault_agent_identity.common_name
    }

    cluster_network = {
      vault_vip           = local.state.vault_sys.service_vip
      nat_gateway         = local.network_parameters["default"].network.nat.gateway
      access_scope        = local.network_parameters["default"].network_access_scope
      dev_harbor_vip      = local.net_config.lb_config.vip
      dev_harbor_tls_port = local.net_config.lb_config.ports["https"].frontend_port
    }
  })

  ansible_extra_vars = {
    terraform_runner_subnet = local.net_config.network.hostonly.cidr

    ansible_user              = local.sec_system_creds.username
    vault_ca_cert_b64         = local.sec_vault_agent_identity.ca_cert_b64
    vault_agent_role_id       = local.sec_vault_agent_identity.role_id
    vault_agent_secret_id     = vault_approle_auth_backend_role_secret_id.bootstrap_harbor_agent.secret_id
    vault_server_address      = local.sys_vault_addr
    vault_role_name           = local.sec_vault_agent_identity.role_name
    vault_agent_common_name   = local.sec_vault_agent_identity.common_name
    dev_harbor_admin_password = local.sec_app_creds.harbor_admin_password
    dev_harbor_pg_db_password = local.sec_app_creds.harbor_pg_db_password
  }
}
