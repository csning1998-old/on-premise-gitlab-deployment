
output "service_vip" {
  description = "The virtual IP assigned to the Bootstrap Harbor service from Central LB topology."
  value       = local.net_config.lb_config.vip
}

output "credentials_system" {
  description = "System-level access credentials for the cluster nodes."
  value       = local.sec_system_creds
  sensitive   = true
}

output "credentials_app" {
  description = "Application-level credentials for Harbor."
  value       = local.sec_app_creds
  sensitive   = true
}

output "network_bindings" {
  description = "L2 network identity mapping (Verified from KVM Module)."
  value       = module.bootstrap_harbor.network_bindings
}

output "network_parameters" {
  description = "L3 network configurations (Verified from KVM Module)."
  value       = module.bootstrap_harbor.network_parameters
}

output "topology_node" {
  description = "The actual provisioned configuration for Bootstrap Harbor node."
  value       = module.bootstrap_harbor.cluster_nodes
}
