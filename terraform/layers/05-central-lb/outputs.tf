
output "service_segments_map" {
  description = "Raw definition of service segments"
  value       = local.hydrated_service_segments
}

output "hydrated_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment"
  value       = local.hydrated_service_segments
}
