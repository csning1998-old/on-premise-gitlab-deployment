
module "hypervisor_kvm" {
  source = "../../cluster-provision/hypervisor-kvm-lb"

  vm_config = local.nodes_config

  credentials = {
    username            = var.vm_credentials.username
    password            = var.vm_credentials.password
    ssh_public_key_path = var.vm_credentials.ssh_public_key_path
  }

  libvirt_infrastructure = {
    network = {
      nat = {
        name_network = var.network_identity.nat_net_name
        name_bridge  = var.network_identity.nat_bridge_name
        mode         = "nat"
        ips = {
          address = var.infra_config.network.nat.gateway
          prefix  = tonumber(split("/", var.infra_config.network.nat.cidrv4)[1])
          dhcp    = var.infra_config.network.nat.dhcp
        }
      }
      hostonly = {
        name_network = var.network_identity.hostonly_net_name
        name_bridge  = var.network_identity.hostonly_bridge_name
        mode         = "route"
        ips = {
          address = var.infra_config.network.hostonly.gateway
          prefix  = tonumber(split("/", var.infra_config.network.hostonly.cidrv4)[1])
          dhcp    = null
        }
      }
    }
    storage_pool_name = var.network_identity.storage_pool_name
  }
  service_segments = var.service_segments
}

module "ssh_manager" {
  source = "../../cluster-provision/ssh-manager"

  status_trigger = module.hypervisor_kvm.vm_status_trigger
  nodes          = local.nodes_list_for_ssh
  vm_credentials = local.vm_credentials
  config_name    = var.topology_config.cluster_identity.cluster_name
}

module "ansible_runner" {
  source = "../../cluster-provision/ansible-runner"

  ansible_config = {
    root_path       = local.ansible.root_path
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    playbook_file   = local.ansible.playbook_file
    inventory_file  = local.ansible.inventory_file
  }

  inventory_content = local.ansible.inventory_contents

  vm_credentials = local.vm_credentials

  extra_vars = {
    terraform_runner_subnet = var.infra_config.network.hostonly.cidrv4
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
