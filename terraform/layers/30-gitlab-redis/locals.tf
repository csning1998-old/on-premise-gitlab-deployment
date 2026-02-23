
# Data Ingestion (Layer 05 Yellow Pages)
locals {
  global_topology     = data.terraform_remote_state.topology.outputs
  central_lb_outputs  = data.terraform_remote_state.central_lb.outputs
  vault_pki_state     = data.terraform_remote_state.vault_pki.outputs
  service_meta        = local.global_topology.service_structure[var.service_catalog_name]
  service_fqdn        = local.global_topology.domain_suffix
  cluster_name        = "${local.service_meta.meta.name}-${local.service_meta.meta.project_code}"
  security_pki_bundle = try(local.global_topology.gitlab_redis_pki, null)
  vault_prod_addr     = "https://${data.terraform_remote_state.vault_raft_config.outputs.service_vip}:443"
}

locals {
  redis_dep_meta     = local.service_meta.dependencies["redis"]
  redis_service_fqdn = try(local.redis_dep_meta.role.dns_san[0], "")
  redis_topology     = local.central_lb_outputs.network_service_topology[local.redis_topology_key]
  redis_topology_key = "${var.service_catalog_name}-redis"
}

# Network Map Construction (Multi-Tier Support)
locals {
  service_vip = local.redis_topology.lb_config.vip

  network_bindings = {
    "redis" = {
      nat_net_name         = local.redis_topology.network.nat.name
      nat_bridge_name      = local.redis_topology.network.nat.bridge_name
      hostonly_net_name    = local.redis_topology.network.hostonly.name
      hostonly_bridge_name = local.redis_topology.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "redis" = {
      network = {
        nat = {
          gateway = local.redis_topology.network.nat.gateway
          cidrv4  = local.redis_topology.network.nat.cidr
          dhcp    = local.redis_topology.network.nat.dhcp
        }
        hostonly = {
          gateway = local.redis_topology.network.hostonly.gateway
          cidrv4  = local.redis_topology.network.hostonly.cidr
        }
      }
      network_access_scope = local.redis_topology.network.hostonly.cidr
    }
  }
}

# Topology Component Construction
locals {
  storage_pool_name = "iac-${local.cluster_name}-redis"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_redis_config
  }
}

# Credentials
locals {
  # System Credentials (OS/SSH)
  credentials_system = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Database Credentials (Patroni/Replication)
  credentials_redis = {
    masterauth  = data.vault_generic_secret.db_vars.data["redis_masterauth"]
    requirepass = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    vrrp_secret = data.vault_generic_secret.db_vars.data["redis_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  # Key: "${service}-${dependency}-dep" -> "gitlab-redis-dep"
  vault_identity_key = "${var.service_catalog_name}-redis-dep"

  vault_agent_identity = {
    vault_address = local.vault_prod_addr
    role_id       = try(local.vault_pki_state.workload_identities_dependencies[local.vault_identity_key].role_id, "")
    role_name     = try(local.vault_pki_state.pki_configuration.dependency_roles[local.vault_identity_key].name, "")
    ca_cert_b64   = local.global_topology.vault_pki.ca_cert
    common_name   = local.redis_service_fqdn
  }
}

# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "sentinel_agent" {
  # Path: local.vault_pki_state -> workload_identities_dependencies -> gitlab-redis-dep
  backend   = local.vault_pki_state.workload_identities_dependencies[local.vault_identity_key].auth_path
  role_name = local.vault_pki_state.workload_identities_dependencies[local.vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-redis"
    "timestamp" = timestamp()
  })
}
