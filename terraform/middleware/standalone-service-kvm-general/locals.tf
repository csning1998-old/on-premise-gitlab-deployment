
# Node Processing & Grouping
locals {
  node_name = "${var.cluster_name}-${var.component_name}-${var.node_suffix}"

  vm_config = {
    all_nodes_map = {
      "${local.node_name}" = {
        # The Fundamental Specifications are Inherited from Node.
        ip         = cidrhost(var.network_parameters[var.topology_node.network_tier].network.hostonly.cidrv4, var.topology_node.ip_suffix)
        vcpu       = var.topology_node.vcpu
        ram        = var.topology_node.ram
        data_disks = var.topology_node.data_disks

        # The Component Level Specifications are Inherited from Component.
        base_image_path = var.topology_node.base_image_path
        role            = var.topology_node.role
        network_tier    = var.topology_node.network_tier
      }
    }
  }
}

# Ansible Configuration
locals {
  ansible = {
    root_path      = abspath("${path.module}/../../../ansible")
    playbook_file  = "playbooks/${var.ansible_playbook_file}"
    inventory_file = "inventory-${var.cluster_name}.yaml"
  }
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

# KVM Module Adaptation (Interface Translation)
locals {
  hypervisor_kvm_infrastructure = {
    for tier, binding in var.network_bindings : tier => {
      network = {
        nat = {
          name_network = binding.nat_net_name
          name_bridge  = binding.nat_bridge_name
          mode         = "nat"
          ips = {
            prefix  = tonumber(split("/", var.network_parameters[tier].network.nat.cidrv4)[1])
            address = var.network_parameters[tier].network.nat.gateway
            dhcp    = var.network_parameters[tier].network.nat.dhcp
          }
        }
        hostonly = {
          name_network = binding.hostonly_net_name
          name_bridge  = binding.hostonly_bridge_name
          mode         = "route"
          ips = {
            prefix  = tonumber(split("/", var.network_parameters[tier].network.hostonly.cidrv4)[1])
            address = var.network_parameters[tier].network.hostonly.gateway
            dhcp    = null
          }
        }
      }
      storage_pool_name = var.topology_node.storage_pool_name
    }
  }
}
