
output "service_segments_map" {
  description = "Raw definition of service segments"
  value       = local.service_segments
}

output "load_balancer_hostnums" {
  description = "The Hostnums rules for VIP and Nodes"
  value = {
    default_vip_hostnum   = local.default_vip_hostnum
    lb_node_start_hostnum = local.lb_node_start_hostnum
  }
}

output "hydrated_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment"
  value       = local.hydrated_service_segments
}
