
output "cluster_nodes" {
  description = "The physical KVM nodes provisioned for this cluster."
  value       = module.hypervisor_kvm.provisioned_nodes
}

output "network_bindings" {
  description = "L2 network identity mapping (Sourced from KVM)."
  value = {
    "${local.primary_tier_key}" = {
      nat_net_name         = module.hypervisor_kvm.infrastructure_config.network.nat.name_network
      nat_bridge_name      = module.hypervisor_kvm.infrastructure_config.network.nat.name_bridge
      hostonly_net_name    = module.hypervisor_kvm.infrastructure_config.network.hostonly.name_network
      hostonly_bridge_name = module.hypervisor_kvm.infrastructure_config.network.hostonly.name_bridge
    }
  }
}

output "network_parameters" {
  description = "L3 network configurations (Sourced from KVM)."
  value = {
    "${local.primary_tier_key}" = {
      network = {
        nat = {
          gateway = module.hypervisor_kvm.infrastructure_config.network.nat.ips.address
          cidrv4  = "${module.hypervisor_kvm.infrastructure_config.network.nat.ips.address}/${module.hypervisor_kvm.infrastructure_config.network.nat.ips.prefix}"
          dhcp    = module.hypervisor_kvm.infrastructure_config.network.nat.ips.dhcp
        }
        hostonly = {
          gateway = module.hypervisor_kvm.infrastructure_config.network.hostonly.ips.address
          cidrv4  = "${module.hypervisor_kvm.infrastructure_config.network.hostonly.ips.address}/${module.hypervisor_kvm.infrastructure_config.network.hostonly.ips.prefix}"
        }
      }
      # Access Scope belongs to logic layer and this is not passed to KVM module.
      network_access_scope = local.primary_params.network_access_scope
    }
  }
}
