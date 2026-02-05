
# Call the Identity Module to generate AppRole & Secret ID
module "redis_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.gitlab_redis_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name
}

module "redis_gitlab" {
  source = "../../modules/service-ha/sentinel-cluster"

  enable_tls      = true
  topology_config = var.gitlab_redis_compute
  infra_config    = var.gitlab_redis_infra
  service_domain  = local.service_domain

  vault_approle_role_id   = module.redis_identity.role_id
  vault_approle_secret_id = module.redis_identity.secret_id
  vault_role_name         = local.vault_role_name
  vault_ca_cert_b64       = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
