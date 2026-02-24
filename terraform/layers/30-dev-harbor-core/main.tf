
module "bootstrap_harbor" {
  source = "../../middleware/standalone-service-kvm-general"

  cluster_name       = local.svc_cluster_name
  component_name     = local.comp_name
  node_suffix        = local.svc_node_suffix
  topology_node      = local.topology_node
  network_parameters = local.network_parameters
  network_bindings   = local.network_bindings

  credentials_system = local.sec_system_creds

  # Generic Ansible Configuration
  ansible_inventory_content = local.ansible_inventory_content
  ansible_extra_vars        = local.ansible_extra_vars
  ansible_playbook_file     = var.ansible_files.playbook_file
}
