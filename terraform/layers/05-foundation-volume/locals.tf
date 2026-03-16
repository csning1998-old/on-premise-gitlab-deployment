
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
  unique_pools = toset(distinct(concat(
    [for key, identity in local.state.metadata.global_identity_map : identity.storage_pool_name],
    [for vol_key, vol_data in local.global_volume_map : vol_data.pool_name]
  )))
}
