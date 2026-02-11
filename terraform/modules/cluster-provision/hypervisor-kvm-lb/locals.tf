
locals {
  nat_net_prefixlen      = var.libvirt_infrastructure.network.nat.ips.prefix
  hostonly_net_prefixlen = var.libvirt_infrastructure.network.hostonly.ips.prefix
  nat_subnet_prefix      = join(".", slice(split(".", var.libvirt_infrastructure.network.nat.ips.address), 0, 3))

  nodes_config = {
    for node_name, node_config in var.vm_config.all_nodes_map :
    node_name => {
      node_index    = index(keys(var.vm_config.all_nodes_map), node_name)
      last_ip_octet = split(".", node_config.ip)[3]

      nat_mac      = "52:54:00:00:00:${format("%02x", index(keys(var.vm_config.all_nodes_map), node_name))}"
      hostonly_mac = "52:54:00:10:00:${format("%02x", index(keys(var.vm_config.all_nodes_map), node_name))}"

      nat_ip_cidr      = "${local.nat_subnet_prefix}.${split(".", node_config.ip)[3]}/${local.nat_net_prefixlen}"
      nat_gateway      = var.libvirt_infrastructure.network.nat.ips.address
      hostonly_ip_cidr = "${node_config.ip}/${local.hostonly_net_prefixlen}"
      hostonly_gateway = var.libvirt_infrastructure.network.hostonly.ips.address

      service_interfaces = [
        for idx, seg in var.service_segments : {
          bridge_name = seg.bridge_name
          index       = idx
          os_dev_name = "ens${5 + idx}"
          ip_cidr     = "${seg.node_ips[node_name]}/${split("/", seg.cidr)[1]}"
          mac_address = format("52:54:%02x:%02x:01:01", seg.vrid, index(keys(var.vm_config.all_nodes_map), node_name))
        }
      ]
    }
  }
}
