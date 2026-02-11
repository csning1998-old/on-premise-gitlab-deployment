
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

locals {

  /**
   * Calculate the specific network information for each service.
   * 1. Parent Service Segment for Main Frontend VIP
   *    Only generate when this Service needs an independent VIP (usually needed)
   *    - key: "service_name"
   *    - cidr_index: svc_data.cidr_index
   * 2. Dependency Segments for Backend VIPs
   *    Include dependency service "network info" and "role info"
   *    - key: "service_name-dependency_name"
   *    - cidr_index: dep_data.cidr_index
   */

  network_segments_list = flatten([
    for s in var.service_catalog : concat(
      [{
        key        = s.name
        cidr_index = s.cidr_index
      }],
      [for d_key, d_data in s.dependencies : {
        key        = "${s.name}-${d_key}"
        cidr_index = d_data.cidr_index
      }]
    )
  ])

  /**
   * Convert back to Map for IP/MAC calculation
   * 1. cidr_block: 172.16.X.0/24
   * 2. vrid: X
   * 3. interface_alias: eth_ + segment.key + MD5 Hash (e.g., eth_'service_name'_'md5_hash')
   * 4. vip: 172.16.X.250
   * 5. mac_address: Deterministic Hashing. Ensure "service_name" always generates the same MAC, regardless of its position in the list
   */
  network_topology = {
    for seg in local.network_segments_list : seg.key => {

      cidr_block      = cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index)
      vrid            = seg.cidr_index
      interface_alias = "eth_${replace(seg.key, "-", "_")}_${substr(md5(seg.key), 0, 4)}"

      vip = cidrhost(
        cidrsubnet(local.network_baseline.cidr_block, 8, seg.cidr_index),
        local.network_baseline.vip_offset
      )

      mac_address = "${local.network_baseline.mac_prefix}:${join(":", [
        substr(md5(seg.key), 0, 2),
        substr(md5(seg.key), 2, 2),
        substr(md5(seg.key), 4, 2)
      ])}"
    }
  }
}
