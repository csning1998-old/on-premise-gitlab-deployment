
locals {
  # Lookup Table: Network Name -> Network Resource ID
  # This allows dynamic blocks to find IDs using network names
  network_id_map = merge(
    # NAT Network
    {
      (var.libvirt_infrastructure.network.nat.name_network) = libvirt_network.nat_net.id
    },
    # HostOnly Network
    {
      (var.libvirt_infrastructure.network.hostonly.name_network) = libvirt_network.hostonly_net.id
    },
    # Service Networks (Dynamic)
    {
      for seg in var.service_segments : seg.name => libvirt_network.service_networks[seg.name].id
    }
  )
}
