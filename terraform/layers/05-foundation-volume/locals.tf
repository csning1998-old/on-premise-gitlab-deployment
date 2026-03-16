
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs
  }
}

locals {
  # Inherit Layer 00's Pure MECE Volume Map
  global_volume_map = local.state.metadata.global_volume_map

  # Extract all pool names that all physical disks belong to, and ensure uniqueness.
  unique_pools = toset(distinct([
    for vol_key, vol_data in local.global_volume_map : vol_data.pool_name
  ]))
}
