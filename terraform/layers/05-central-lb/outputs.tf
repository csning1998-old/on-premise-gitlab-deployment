
output "hydrated_topology" {
  description = "Computed topology including calculated VIPs and Node IPs per segment"
  value       = local.hydrated_service_segments
}
