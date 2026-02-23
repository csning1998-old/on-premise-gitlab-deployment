
# State Object
locals {
  state = {
    topology  = data.terraform_remote_state.topology.outputs
    network   = data.terraform_remote_state.network.outputs
    vault_sys = data.terraform_remote_state.vault_sys.outputs
    vault_pki = data.terraform_remote_state.vault_pki.outputs
  }
}

# Service Context
locals {
  svc_name         = var.service_catalog_name
  svc_meta         = local.state.topology.service_structure[local.svc_name]
  svc_fqdn         = local.state.topology.domain_suffix
  svc_cluster_name = "${local.svc_meta.meta.name}-${local.svc_meta.meta.project_code}"

  postgres_dep_meta = local.svc_meta.dependencies["postgres"]
  svc_postgres_fqdn = try(local.postgres_dep_meta.role.dns_san[0], "")
}

# Network Context
locals {
  net_postgres    = local.state.network.network_service_topology["${local.svc_name}-postgres"]
  net_etcd        = local.state.network.network_service_topology["${local.svc_name}-etcd"]
  net_service_vip = local.net_postgres.lb_config.vip

  # Network Bindings: L2 Physical Attachment of Network Bridge
  network_bindings = {
    "postgres" = {
      nat_net_name         = local.net_postgres.network.nat.name
      nat_bridge_name      = local.net_postgres.network.nat.bridge_name
      hostonly_net_name    = local.net_postgres.network.hostonly.name
      hostonly_bridge_name = local.net_postgres.network.hostonly.bridge_name
    }
    "etcd" = {
      nat_net_name         = local.net_etcd.network.nat.name
      nat_bridge_name      = local.net_etcd.network.nat.bridge_name
      hostonly_net_name    = local.net_etcd.network.hostonly.name
      hostonly_bridge_name = local.net_etcd.network.hostonly.bridge_name
    }
  }

  network_parameters = {
    "postgres" = {
      network = {
        nat = {
          gateway = local.net_postgres.network.nat.gateway
          cidrv4  = local.net_postgres.network.nat.cidr
          dhcp    = local.net_postgres.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_postgres.network.hostonly.gateway
          cidrv4  = local.net_postgres.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_postgres.network.hostonly.cidr
    }
    "etcd" = {
      network = {
        nat = {
          gateway = local.net_etcd.network.nat.gateway
          cidrv4  = local.net_etcd.network.nat.cidr
          dhcp    = local.net_etcd.network.nat.dhcp
        }
        hostonly = {
          gateway = local.net_etcd.network.hostonly.gateway
          cidrv4  = local.net_etcd.network.hostonly.cidr
        }
      }
      network_access_scope = local.net_etcd.network.hostonly.cidr
    }
  }
}

# Security & App Context (sec_ / sys_ / pki_)
locals {
  sys_vault_addr   = "https://${local.state.vault_sys.service_vip}:443"
  pki_global_ca    = try(local.state.topology.gitlab_postgres_pki, null)
  pki_vault_ca_b64 = local.state.topology.vault_pki.ca_cert

  # System Credentials (OS/SSH)
  sec_system_creds = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  # Database Credentials (Patroni/Replication)
  sec_postgres_creds = {
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
    vrrp_secret          = data.vault_generic_secret.db_vars.data["pg_vrrp_secret"]
  }

  # Vault Agent Identity Prep
  # Key: "${service}-${dependency}-dep" -> "gitlab-postgres-dep"
  sec_vault_identity_key = "${local.svc_name}-postgres-dep"

  sec_vault_agent_identity = {
    vault_address = local.sys_vault_addr
    role_id       = try(local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_id, "")
    role_name     = try(local.state.vault_pki.pki_configuration.dependency_roles[local.sec_vault_identity_key].name, "")
    ca_cert_b64   = local.pki_vault_ca_b64
    common_name   = local.svc_postgres_fqdn
  }
}

# Topology Component Construction
locals {
  storage_pool_name = "iac-${local.svc_cluster_name}-postgres"

  topology_cluster = {
    storage_pool_name = local.storage_pool_name
    components        = var.gitlab_postgres_config
  }
}

# Call the Identity Module to generate AppRole & Secret ID
resource "vault_approle_auth_backend_role_secret_id" "patroni_agent" {
  # Path: local.state.vault_pki -> workload_identities_dependencies -> gitlab-postgres-dep
  backend   = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].auth_path
  role_name = local.state.vault_pki.workload_identities_dependencies[local.sec_vault_identity_key].role_name

  # Metadata for Vault Audit Log
  metadata = jsonencode({
    "source"    = "terraform-layer-30-gitlab-postgres"
    "timestamp" = timestamp()
  })
}
