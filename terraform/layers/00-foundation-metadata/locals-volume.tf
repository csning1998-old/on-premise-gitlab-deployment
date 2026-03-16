
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

locals {
  volume_segments_list = flatten([
    for s in var.service_catalog : concat(
      length(s.data_disks) > 0 ? [{
        segment_key = s.name
        project     = s.project_code
        ip_range    = s.ip_range
        data_disks  = s.data_disks
      }] : [],
      [
        for d_key, d_data in s.dependencies : {
          segment_key = "${s.name}-${d_key}"
          project     = s.project_code
          ip_range    = d_data.ip_range
          data_disks  = d_data.data_disks
        }
        if length(d_data.data_disks) > 0
      ]
    )
  ])

  _volume_topology_raw = flatten([
    for seg in local.volume_segments_list : [
      for i in range(seg.ip_range.end_ip - seg.ip_range.start_ip + 1) : [
        for disk in seg.data_disks : {
          base_id      = "${seg.project}-${seg.segment_key}"
          pool_name    = "iac-${seg.project}-${seg.segment_key}-pool"
          volume_name  = "${seg.project}-${seg.segment_key}-node-${seg.ip_range.start_ip + i}-${disk.name_suffix}.qcow2"
          capacity_gib = disk.capacity_gib
        }
      ]
    ]
  ])

  volume_topology = {
    for vol in local._volume_topology_raw : vol.volume_name => vol
  }
}
