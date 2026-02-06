
# For Postgres Service Configuration
locals {
  platform_id    = var.harbor_postgres_compute.cluster_identity.service_name
  service_domain = local.domain_list[0] # pg.harbor.iac.local
}

# For PKI Configuration
locals {
  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.roles.postgres[local.platform_id]
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.domains.postgres[local.platform_id]
}
