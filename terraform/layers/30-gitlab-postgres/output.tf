
output "gitlab_postgres_cluster_name" {
  description = "GitLab Postgres cluster name."
  value       = local.cluster_name
}

output "gitlab_postgres_db_ip_list" {
  description = "List of Postgres node IPs for GitLab"
  value       = [for k, node in local.cluster_components["postgres"].nodes_configuration : node.ip]
}

output "gitlab_postgres_etcd_ip_list" {
  description = "List of Postgres etcd node IPs for GitLab"
  value       = [for k, node in local.cluster_components["etcd"].nodes_configuration : node.ip]
}

output "gitlab_postgres_virtual_ip" {
  description = "Postgres virtual IP for GitLab"
  value       = local.service_vip
}
