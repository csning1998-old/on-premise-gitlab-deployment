
# Node Processing & Grouping
locals {
  flat_node_map = merge([
    for comp_name, comp_data in var.topology_cluster.components : {
      for node_suffix, node_data in comp_data.nodes :
      "${var.cluster_name}-${comp_name}-${node_suffix}" => {
        # The Fundamental Specifications are Inherited from Node.
        ip         = cidrhost(var.network_parameters[comp_data.network_tier].network.hostonly.cidrv4, node_data.ip_suffix)
        vcpu       = node_data.vcpu
        ram        = node_data.ram
        data_disks = node_data.data_disks

        # The Component Level Specifications are Inherited from Component.
        base_image_path = comp_data.base_image_path
        role            = comp_data.role
        network_tier    = comp_data.network_tier
      }
    }
  ]...)

  # Group nodes by role for Ansible Inventory
  nodes_by_role = {
    for role in distinct(values(local.flat_node_map).*.role) : role => {
      for name, node in local.flat_node_map : name => node
      if node.role == role
    }
  }
}

# Ansible Configuration (Dynamic Inventory)
locals {
  inventory_template = "${path.module}/../../../templates/${var.ansible_files.inventory_template_file}"

  ansible = {
    root_path      = abspath("${path.module}/../../../../ansible")
    playbook_file  = "playbooks/${var.ansible_files.playbook_file}"
    inventory_file = "inventory-${var.cluster_name}.yaml"

    inventory_contents = templatefile(local.inventory_template, {

      etcd_nodes     = try(local.nodes_by_role["etcd"], {})
      postgres_nodes = try(local.nodes_by_role["postgres"], {})

      cluster_identity = {
        name   = var.cluster_name
        domain = var.service_domain
      }

      cluster_network = {
        vip          = var.service_vip
        nat_prefix   = join(".", slice(split(".", local.primary_params.network.nat.gateway), 0, 3))
        access_scope = local.primary_params.network_access_scope
      }
    })
  }

  ansible_extra_vars = merge(
    {
      ansible_user = var.credentials_system.username
    },
    var.security_pki_bundle != null ? {
      vault_server_cert = var.security_pki_bundle.server_cert
      vault_server_key  = var.security_pki_bundle.server_key
      vault_ca_cert     = var.security_pki_bundle.ca_cert
    } : {}
  )
}

# Security Credentials
locals {
  vm_credentials_for_hypervisor = {
    username            = var.credentials_system.username
    password            = var.credentials_system.password
    ssh_public_key_path = var.credentials_system.ssh_public_key_path
  }

  vm_credentials_for_ssh = {
    username             = var.credentials_system.username
    ssh_private_key_path = var.credentials_system.ssh_private_key_path
  }
}

# Primary Tier Selection for KVM Module Undeclared local value
# - Find the primary network tier for KVM module
# - If 'default' is not found, find the first tier used
locals {
  primary_tier_key = contains(keys(var.network_bindings), "default") ? "default" : keys(var.network_bindings)[0]
  primary_binding  = var.network_bindings[local.primary_tier_key]
  primary_params   = var.network_parameters[local.primary_tier_key]
}

# KVM Module Adaptation (Interface Translation)
locals {
  hypervisor_kvm_infrastructure = {
    network = {
      nat = {
        name_network = local.primary_binding.nat_net_name
        name_bridge  = local.primary_binding.nat_bridge_name
        mode         = "nat"
        ips = {
          address = local.primary_params.network.nat.gateway
          prefix  = tonumber(split("/", local.primary_params.network.nat.cidrv4)[1])
          dhcp    = local.primary_params.network.nat.dhcp
        }
      }
      hostonly = {
        name_network = local.primary_binding.hostonly_net_name
        name_bridge  = local.primary_binding.hostonly_bridge_name
        mode         = "route"
        ips = {
          address = local.primary_params.network.hostonly.gateway
          prefix  = tonumber(split("/", local.primary_params.network.hostonly.cidrv4)[1])
          dhcp    = null
        }
      }
    }
    storage_pool_name = var.topology_cluster.storage_pool_name
  }
}
