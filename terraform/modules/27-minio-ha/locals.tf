
locals {
  svc  = var.topology_config.cluster_identity.service_name
  comp = var.topology_config.cluster_identity.component

  # Naming
  storage_pool_name = "iac-${local.svc}-${local.comp}"
  nat_net_name      = "iac-${local.svc}-${local.comp}-nat"
  hostonly_net_name = "iac-${local.svc}-${local.comp}-hostonly"

  svc_abbr             = substr(local.svc, 0, 3)
  comp_abbr            = substr(local.comp, 0, 3)
  nat_bridge_name      = "${local.svc_abbr}-${local.comp_abbr}-natbr"
  hostonly_bridge_name = "${local.svc_abbr}-${local.comp_abbr}-hostbr"

  # MinIO nodes
  minio_nodes = var.topology_config.nodes

  # HAProxy nodes
  haproxy_nodes_adapted = {
    for k, v in var.topology_config.ha_config.haproxy_nodes : k => merge(v, {
      data_disks = []
    })
  }

  # Merge all nodes
  all_nodes_map = merge(local.minio_nodes, local.haproxy_nodes_adapted)

  # Ansible path and parameters
  ansible_root_path         = abspath("${path.root}/../../../ansible")
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))
}
