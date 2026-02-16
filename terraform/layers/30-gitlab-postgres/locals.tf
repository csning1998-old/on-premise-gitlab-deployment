
locals {
  global_topology    = data.terraform_remote_state.topology.outputs
  central_lb_outputs = data.terraform_remote_state.central_lb.outputs
  hydrated_topology  = local.central_lb_outputs.hydrated_topology
  service_meta       = local.global_topology.service_structure[var.service_catalog_name]
  domain_suffix      = local.global_topology.domain_suffix
  cluster_name       = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  vault_pki          = try(data.terraform_remote_state.topology.outputs.vault_pki, null)

  # Extract the Bridge Network Info for Service with Salted Hash Name
  my_segment_info = [
    for seg in local.hydrated_topology : seg
    if seg.name == var.service_catalog_name
  ][0]
}

locals {
  # Lookup Map for Topology
  topology_map = {
    for seg in local.hydrated_topology : seg.name => seg
  }
}

locals {
  # 1. Lookup Service Metadata and Extract Network Facts from SSoT
  service_vip = local.service_meta.network.vip

  # 2. Network Identity & Specs (Corrected Source)
  # Use unique network names for this service cluster to avoid conflict with LB infra
  network_identity = {
    for comp in var.service_dependencies : comp => {
      nat_net_name         = local.central_lb_outputs.infra_network.nat.name_network
      nat_bridge_name      = local.central_lb_outputs.infra_network.nat.name_bridge
      hostonly_net_name    = local.topology_map["${var.service_catalog_name}-${comp}"].name
      hostonly_bridge_name = local.topology_map["${var.service_catalog_name}-${comp}"].bridge_name
    }
  }

  # 3. Subnet Prefix (Based on the Vault NAT gateway)
  nat_network_subnet_prefix = join(".", slice(split(".", local.my_segment_info.nat_gateway), 0, 3))
}

locals {
  network_config = {
    for comp in var.service_dependencies : comp => {
      network = {
        nat = {
          gateway = local.topology_map["${var.service_catalog_name}-${comp}"].nat_gateway
          cidrv4  = local.topology_map["${var.service_catalog_name}-${comp}"].nat_cidr
          dhcp    = try(local.global_topology.network_segments["${var.service_catalog_name}-${comp}"].nat_dhcp, null)
        }
        hostonly = {
          gateway = cidrhost(local.topology_map["${var.service_catalog_name}-${comp}"].cidr, 1)
          cidrv4  = local.topology_map["${var.service_catalog_name}-${comp}"].cidr
        }
      }
      allowed_subnet = local.topology_map["${var.service_catalog_name}-${comp}"].cidr
    }
  }
}

locals {
  cluster_components = {
    for comp in var.service_dependencies : comp => {

      cluster_name      = local.cluster_name
      storage_pool_name = "iac-${local.service_meta.meta.project_code}-${var.service_catalog_name}-${comp}"

      nodes_configuration = {
        for node_key, node_val in var.gitlab_postgres_config["${comp}_config"].nodes : "${local.cluster_name}-${comp}-${node_key}" => {
          ip              = cidrhost(local.topology_map["${var.service_catalog_name}-${comp}"].cidr, node_val.ip_suffix)
          vcpu            = node_val.vcpu
          ram             = node_val.ram
          base_image_path = var.gitlab_postgres_config["${comp}_config"].base_image_path
          role            = comp
        }
      }
    }
  }

  all_nodes_list_for_ssh = flatten([
    for comp_key, comp_val in local.cluster_components : [
      for node_key, node_val in comp_val.nodes_configuration : {
        key = node_key
        ip  = node_val.ip
      }
    ]
  ])
}

locals {
  service_domain = try(
    local.global_topology.vault_pki.workload_identities_dependencies["postgres"].dns_san[0],
    "${local.service_meta.meta.name}.${local.domain_suffix}" # Fallback
  )

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  db_credentials = {
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  vault_agent_config = {
    vault_address = var.vault_dev_addr
    role_id       = try(data.terraform_remote_state.vault_pki.outputs.workload_identities_dependencies["${var.service_catalog_name}-postgres-dep"].role_id, "")
    role_name     = try(data.terraform_remote_state.vault_pki.outputs.workload_identities_dependencies["${var.service_catalog_name}-postgres-dep"].role_name, "")
    ca_cert_b64   = local.global_topology.vault_pki.ca_cert
  }
}
