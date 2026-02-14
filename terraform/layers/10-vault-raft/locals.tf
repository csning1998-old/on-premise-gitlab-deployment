
locals {
  global_topology    = data.terraform_remote_state.topology.outputs
  central_lb_outputs = data.terraform_remote_state.central_lb.outputs
  hydrated_topology  = local.central_lb_outputs.hydrated_topology
  service_meta       = local.global_topology.service_structure[var.service_catalog_name]
  domain_suffix      = local.global_topology.domain_suffix
  cluster_name       = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  network_segment    = local.global_topology.network_segments[var.service_catalog_name]

  # Extract the Bridge Network Info for Service with Salted Hash Name
  my_segment_info = [
    for seg in local.hydrated_topology : seg
    if seg.name == var.service_catalog_name
  ][0]

  # TLS Output Directory
  layer_tls_dir = "${path.root}/tls"
}

locals {
  # 1. Lookup Service Metadata and Extract Network Facts from SSoT
  service_vip         = local.service_meta.network.vip
  service_bridge_name = local.my_segment_info.bridge_name

  # 2. Network Identity & Specs (Corrected Source)
  # Use unique network names for this service cluster to avoid conflict with LB infra
  nat_net_name      = "${local.cluster_name}-nat"
  hostonly_net_name = "${local.cluster_name}-hostonly"

  # NAT Bridge usually remains shared (mgmt-br), but HostOnly Bridge MUST be the service-specific one
  nat_bridge_name      = "br-nat-${substr(md5(local.cluster_name), 0, 6)}"
  hostonly_bridge_name = local.my_segment_info.bridge_name

  # Extract Gateways and CIDRs from the Service Segment Info (Vault Specific), NOT Central LB
  hostonly_gateway = cidrhost(local.my_segment_info.cidr, 1) # Implied Gateway for HostOnly is typically the .1 of the CIDR
  hostonly_cidr    = local.my_segment_info.cidr              # e.g. 172.16.136.0/24
  nat_gateway      = local.my_segment_info.nat_gateway       # e.g. 172.16.12.1
  nat_cidr         = local.my_segment_info.nat_cidr          # e.g. 172.16.12.0/24
  nat_dhcp         = local.network_segment.nat_dhcp          # .12.100 - .12.199

  # 3. Subnet Prefix (Based on the Vault NAT gateway)
  nat_network_subnet_prefix = join(".", slice(split(".", local.nat_gateway), 0, 3))
}
locals {
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
}

locals {
  # 1. Cluster Identity Construction
  node_name_prefix  = "${local.cluster_name}-node"
  storage_pool_name = "iac-${local.service_meta.meta.project_code}-${local.service_meta.meta.name}"

  # 2. Inject Base Image Path
  nodes_configuration = {
    for k, v in var.vault_config.nodes : k => merge(v, {
      base_image_path = var.base_image_path
    })
  }
  # 3. Final Node Map
  nodes_map = local.nodes_configuration
}
