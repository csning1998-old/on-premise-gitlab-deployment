
# State Object
locals {
  state = {
    metadata = data.terraform_remote_state.metadata.outputs
    network  = data.terraform_remote_state.network.outputs
  }
}

# 1. Service Context
locals {
  # Dynamically find the "central-lb" metadata from the global structure
  # to avoid hardcoding or using redundant variables.
  svc_config = [
    for k, v in local.state.metadata.global_service_structure :
    v if v.meta.name == "central-lb"
  ][0]

  svc_name         = local.svc_config.network.segment_key
  svc_fqdn         = local.state.metadata.global_domain_suffix
  svc_network_map  = local.state.metadata.global_network_map
  svc_identity     = local.state.metadata.global_identity_map[local.svc_name]
  svc_cluster_name = local.svc_identity.cluster_name
  svc_node_prefix  = local.svc_identity.node_name_prefix
}

# 2. Network Context (delegated to `05-foundation-network`)
locals {
  # Deterministic Ordering
  net_sorted_node_keys = sort(keys(var.node_config))

  net_node_naming_map = {
    for idx, key in local.net_sorted_node_keys :
    key => "${local.svc_node_prefix}-${format("%02d", idx)}"
  }

  # Delegated from `05-foundation-network`
  net_infrastructure = local.state.network.infrastructure_map
  net_lb_config      = local.state.network.central_lb_info
  net_access_scope   = local.net_lb_config.hostonly.cidr
  net_my_segment     = local.svc_network_map[local.svc_name]
}

locals {
  # Service Segments: augment from `05-foundation-network` with node_ips computed here (depends on `var.node_config`)
  # Services tagged "self-managed-lb" run their own HA stack (e.g. Kubeadm Stacked Control Plane)
  # and must NOT appear here, as they own their VIP independently.
  net_service_segments = [
    for seg in local.state.network.service_segments : merge(seg, {
      node_ips = {
        for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] =>
        cidrhost(local.svc_network_map[seg.name].cidr_block, node_spec.ip_suffix)
      }
    })
    if !contains(seg.tags, "self-managed-lb")
  ]
}

# 3. Security & Credentials Context (sec_ / pki_)
locals {
  pki_global_ca = local.state.metadata.global_vault_pki

  sec_vm_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  sec_haproxy_creds = {
    haproxy_stats_pass   = data.vault_generic_secret.infra_vars.data["haproxy_stats_pass"]
    keepalived_auth_pass = data.vault_generic_secret.infra_vars.data["keepalived_auth_pass"]
  }

  ansible_template_vars = {
    ansible_ssh_user = local.sec_vm_creds.username
    service_domain   = local.svc_fqdn
    service_name     = local.svc_cluster_name
  }

  ansible_extra_vars = {
    terraform_runner_subnet = local.net_lb_config.hostonly.cidr
  }
}

# metadata Component Construction
locals {
  # Payload Construction
  storage_pool_name = local.svc_identity.storage_pool_name

  topology_nodes = {
    for node_name, node_spec in var.node_config : local.net_node_naming_map[node_name] => merge(node_spec, {
      base_image_path = var.base_image_path
    })
  }
}
