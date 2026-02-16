
locals {
  all_nodes_list_for_ssh = flatten([
    for comp_key, comp_val in var.topology_config : [
      for node_key, node_val in comp_val.nodes_configuration : {
        key = node_key
        ip  = node_val.ip
      }
    ]
  ])

  postgres_nodes_map_template = {
    for key, node in var.topology_config["postgres"].nodes_configuration : key => {
      ip = node.ip
    }
  }

  etcd_nodes_map_template = {
    for key, node in var.topology_config["etcd"].nodes_configuration : key => {
      ip = node.ip
    }
  }

  postgres_nat_subnet_prefix = join(".", slice(split(".", var.network_config["postgres"].network.nat.gateway), 0, 3))
}

locals {
  inventory_template = "${path.module}/../../../templates/inventory-postgres-cluster.yaml.tftpl"

  ansible = {
    root_path      = abspath("${path.module}/../../../../ansible")
    playbook_file  = "playbooks/20-provision-data-services.yaml"
    inventory_file = "inventory-${var.cluster_name}.yaml"

    inventory_contents = templatefile(local.inventory_template, {
      ansible_ssh_user           = var.vm_credentials.username
      service_identifier         = var.cluster_name
      service_domain             = var.service_domain
      postgres_nodes             = local.postgres_nodes_map_template
      etcd_nodes                 = local.etcd_nodes_map_template
      postgres_nat_subnet_prefix = local.postgres_nat_subnet_prefix
      postgres_ha_virtual_ip     = var.service_vip
      postgres_allowed_subnet    = var.network_config["postgres"].allowed_subnet
    })
  }
}

locals {
  ansible_extra_vars = merge(
    {
      # DB Credentials
      pg_superuser_password   = var.db_credentials.superuser_password
      pg_replication_password = var.db_credentials.replication_password
      pg_vrrp_secret          = var.db_credentials.vrrp_secret

      # Vault Agent Config
      vault_agent_role_id   = var.vault_agent_config.role_id
      vault_agent_secret_id = var.vault_agent_config.secret_id
      vault_ca_cert_b64     = var.vault_agent_config.ca_cert_b64
      vault_role_name       = var.vault_agent_config.role_name
      vault_server_addr     = var.vault_agent_config.vault_address
    },
    var.pki_artifacts != null ? {
      vault_server_cert = try(var.pki_artifacts.server_cert, "")
      vault_server_key  = try(var.pki_artifacts.server_key, "")
      vault_ca_cert     = try(var.pki_artifacts.ca_cert, "")
    } : {}
  )
}

locals {
  vm_credentials_for_hypervisor = {
    username            = var.vm_credentials.username
    password            = var.vm_credentials.password
    ssh_public_key_path = var.vm_credentials.ssh_public_key_path
  }

  vm_credentials_for_ssh = {
    username             = var.vm_credentials.username
    ssh_private_key_path = var.vm_credentials.ssh_private_key_path
  }
}
