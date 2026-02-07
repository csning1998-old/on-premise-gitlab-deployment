
module "vault_cluster" {
  source = "../../modules/service-ha/vault-raft-cluster"

  # Topology
  topology_config = merge(
    var.vault_compute,
    {
      cluster_identity = merge(
        var.vault_compute.cluster_identity,
        {
          cluster_name = local.cluster_name
        }
      )
    }
  )
  infra_config = var.vault_infra

  # Network Identity
  network_identity = {
    nat_net_name         = local.nat_net_name
    nat_bridge_name      = local.nat_bridge_name
    hostonly_net_name    = local.hostonly_net_name
    hostonly_bridge_name = local.hostonly_bridge_name
    storage_pool_name    = local.storage_pool_name
  }

  # Credentials Injection
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  vault_credentials = {
    vault_keepalived_auth_pass = data.vault_generic_secret.infra_vars.data["vault_keepalived_auth_pass"]
    vault_haproxy_stats_pass   = data.vault_generic_secret.infra_vars.data["vault_haproxy_stats_pass"]
  }

  tls_source_dir = module.vault_tls_gen.tls_source_dir
}

module "vault_tls_gen" {
  source     = "../../modules/configuration/vault-tls-gen"
  output_dir = local.layer_tls_dir

  tls_mode = var.tls_mode

  vault_cluster = {
    vault_cluster = {
      nodes = {
        for k, v in var.vault_compute.vault_cluster.nodes : k => {
          ip = v.ip
        }
      }
    }
    haproxy_config = {
      virtual_ip = var.vault_compute.haproxy_config.virtual_ip
    }
  }
}

module "vault_pki_setup" {
  source = "../../modules/configuration/vault-pki-setup"

  depends_on = [module.vault_cluster]

  providers = {
    vault = vault.target_cluster
  }
  vault_addr          = "https://${var.vault_compute.haproxy_config.virtual_ip}:443"
  root_domain         = local.root_domain
  root_ca_common_name = var.vault_pki_engine_config.root_ca_common_name

  auth_backends     = var.vault_auth_backends
  pki_engine_config = var.vault_pki_engine_config

  component_roles  = local.component_roles
  dependency_roles = local.dependency_roles
}

module "vault_workload_identity_components" {
  source = "../../modules/configuration/vault-workload-identity"

  for_each           = local.component_roles
  name               = each.key
  vault_role_name    = each.value.name
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]

  providers = {
    vault = vault.target_cluster
  }
}

module "vault_workload_identity_dependencies" {
  source = "../../modules/configuration/vault-workload-identity"

  for_each           = local.dependency_roles
  name               = each.key
  vault_role_name    = each.value.name
  pki_mount_path     = module.vault_pki_setup.vault_pki_path
  approle_mount_path = module.vault_pki_setup.auth_backend_paths["approle"]

  providers = {
    vault = vault.target_cluster
  }
}
