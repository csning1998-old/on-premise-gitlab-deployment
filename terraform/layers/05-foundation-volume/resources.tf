
# 1. Storage Pools
resource "libvirt_pool" "storage_pools" {
  for_each = local.unique_pools

  type = "dir"
  name = each.key
  target = {
    path = abspath("/var/lib/libvirt/images/${each.key}")
  }
}

# 2. Data Disks
resource "libvirt_volume" "data_disks" {
  depends_on = [libvirt_pool.storage_pools]
  for_each   = local.global_volume_map

  format   = "qcow2"
  name     = each.value.volume_name
  pool     = each.value.pool_name
  capacity = each.value.capacity_gib * 1024 * 1024 * 1024
}
