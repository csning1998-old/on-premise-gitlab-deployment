
# For Redis Service Configuration
locals {
  platform_id    = var.gitlab_redis_compute.cluster_identity.service_name
  service_domain = local.domain_list[0] # redis.gitlab.iac.local
}

# For PKI Configuration
locals {
  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.roles.redis[local.platform_id]
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.domains.redis[local.platform_id]
}
