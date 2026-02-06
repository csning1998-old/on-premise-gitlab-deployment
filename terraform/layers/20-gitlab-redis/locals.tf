
locals {
  # Service Identity
  svc_name  = var.gitlab_redis_compute.cluster_identity.service_name
  comp_name = var.gitlab_redis_compute.cluster_identity.component

  # Naming Convention
  nat_net_name      = "iac-${local.svc_name}-${local.comp_name}-nat"
  hostonly_net_name = "iac-${local.svc_name}-${local.comp_name}-hostonly"
  storage_pool_name = "iac-${local.svc_name}-${local.comp_name}"

  # Bridges
  svc_abbr             = substr(local.svc_name, 0, 3)
  comp_abbr            = substr(local.comp_name, 0, 3)
  nat_bridge_name      = "${local.svc_abbr}-${local.comp_abbr}-natbr"
  hostonly_bridge_name = "${local.svc_abbr}-${local.comp_abbr}-hostbr"

  # PKI & Domain Logic
  platform_id     = local.svc_name
  service_domain  = local.domain_list[0]
  vault_role_name = data.terraform_remote_state.vault_core.outputs.pki_configuration.database_roles["${local.platform_id}-redis"].name
  domain_list     = data.terraform_remote_state.vault_core.outputs.pki_configuration.database_roles["${local.platform_id}-redis"].allowed_domains
}
