
output "service_vip" {
  description = "The virtual IP assigned to the Redis service from Central LB topology."
  value       = local.net_service_vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}

output "credentials_redis" {
  description = "Database-level credentials for Redis replication."
  value       = local.sec_redis_creds
  sensitive   = true
}

output "network_bindings" {
  description = "L2 network identity mapping (Verified from KVM Module)."
  value       = module.redis_harbor.network_bindings
}

output "network_parameters" {
  description = "L3 network configurations (Verified from KVM Module)."
  value       = module.redis_harbor.network_parameters
}

output "topology_cluster" {
  description = "The actual provisioned configuration for Redis nodes."
  value       = module.redis_harbor.cluster_nodes
}
