
module "hypervisor_kvm" {
  source = "../../cluster-provision/hypervisor-kvm-lb"

  vm_config = {
    all_nodes_map = local.all_nodes_map
  }

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

  config_name = var.topology_config.cluster_identity.cluster_name
  nodes       = [for k, v in local.all_nodes_map : { key = k, ip = v.ip }]

  vm_credentials = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }
  status_trigger = module.hypervisor_kvm.vm_status_trigger
}

module "ansible_runner" {
  source = "../../cluster-provision/ansible-runner"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_manager.ssh_config_file_path
    playbook_file   = "playbooks/10-provision-core-services.yaml"
    inventory_file  = "inventory-${var.topology_config.cluster_identity.cluster_name}.yaml"
  }

  inventory_content = templatefile("${path.module}/../../../templates/inventory-load-balancer-cluster.yaml.tftpl", {
    ansible_ssh_user    = var.vm_credentials.username
    service_name        = var.topology_config.cluster_identity.service_name
    service_domain      = var.service_domain
    service_segments    = var.service_segments
    load_balancer_nodes = var.topology_config.load_balancer_config.nodes
    interface_name      = var.service_segments[0].interface_name
  })

  vm_credentials = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }

  extra_vars = {
    # Terraform Runner Subnet
    terraform_runner_subnet = var.infra_config.network.hostonly.cidrv4
  }

  status_trigger = module.ssh_manager.ssh_access_ready_trigger
}
