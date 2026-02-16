
module "hypervisor_kvm" {
  source   = "../../cluster-provision/hypervisor-kvm"
  for_each = var.topology_config

  vm_config = {
    all_nodes_map = each.value.nodes_configuration
  }

  credentials     = local.vm_credentials_for_hypervisor
  create_networks = false

  libvirt_infrastructure = {
    network = {
      nat = {
        name_network = var.network_identity[each.key].nat_net_name
        name_bridge  = var.network_identity[each.key].nat_bridge_name
        mode         = "nat"
        ips = {
          address = var.network_config[each.key].network.nat.gateway
          prefix  = tonumber(split("/", var.network_config[each.key].network.nat.cidrv4)[1])
          dhcp    = var.network_config[each.key].network.nat.dhcp
        }
      }
      hostonly = {
        name_network = var.network_identity[each.key].hostonly_net_name
        name_bridge  = var.network_identity[each.key].hostonly_bridge_name
        mode         = "route"
        ips = {
          address = var.network_config[each.key].network.hostonly.gateway
          prefix  = tonumber(split("/", var.network_config[each.key].network.hostonly.cidrv4)[1])
        }
      }
    }
    storage_pool_name = each.value.storage_pool_name
  }
}

module "ssh_manager" {
  source         = "../../cluster-provision/ssh-manager"
  status_trigger = values(module.hypervisor_kvm)[*].vm_status_trigger

  nodes          = local.all_nodes_list_for_ssh
  vm_credentials = local.vm_credentials_for_ssh
  config_name = {
    cluster_name = var.cluster_name
  }
}

module "ansible_runner" {
  source         = "../../cluster-provision/ansible-runner"
  status_trigger = module.ssh_manager.ssh_access_ready_trigger

  ansible_config = {
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    root_path       = local.ansible.root_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }

  inventory_content = local.ansible.inventory_contents
  vm_credentials    = local.vm_credentials_for_ssh
  extra_vars        = local.ansible_extra_vars
}
