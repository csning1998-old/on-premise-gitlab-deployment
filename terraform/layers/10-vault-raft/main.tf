
module "vault_tls_generator" {
  source     = "../../modules/configuration/vault-tls-generator"
  output_dir = local.layer_tls_dir

  tls_mode = var.tls_mode

  vault_cluster = {
    vault_config = {
      nodes = {
        for k, v in var.vault_config.nodes : k => {
          ip = v.ip
        }
      }
    }
  }
}

module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  # Topology
  topology_config = {
    cluster_name      = local.cluster_name
    storage_pool_name = local.storage_pool_name

    vault_config = {
      nodes = local.nodes_configuration
    }
  }

  # Inject VIP from SSoT
  service_vip    = local.service_vip
  service_domain = local.domain_suffix

  # Inject Network Config from Layer 05 (Gateway, CIDR, DHCP)
  network_config = {
    network = {
      nat = {
        gateway = local.nat_gateway
        cidrv4  = local.nat_cidr
        dhcp    = local.nat_dhcp
      }
      hostonly = {
        gateway = local.hostonly_gateway
        cidrv4  = local.hostonly_cidr
      }
    }
    allowed_subnet = local.my_segment_info.cidr
  }

  # Network Identity (Bridge Names from Layer 05)
  network_identity = {
    nat_net_name         = local.nat_net_name
    nat_bridge_name      = local.nat_bridge_name
    hostonly_net_name    = local.hostonly_net_name
    hostonly_bridge_name = local.hostonly_bridge_name
  }

  vm_credentials = local.vm_credentials

  # Credentials Injection and output directory for TLS
  tls_source_dir = module.vault_tls_generator.tls_source_dir
}
