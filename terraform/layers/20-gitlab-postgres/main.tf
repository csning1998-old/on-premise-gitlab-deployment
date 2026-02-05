
# New: Call the Identity Module to generate AppRole & Secret ID
module "postgres_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.gitlab_postgres_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name
}

module "postgres_gitlab" {
  source = "../../modules/service-ha/patroni-cluster"

  topology_config = var.gitlab_postgres_compute
  infra_config    = var.gitlab_postgres_infra
  service_domain  = local.service_domain

  vault_approle_role_id   = module.postgres_identity.role_id
  vault_approle_secret_id = module.postgres_identity.secret_id
  vault_role_name         = local.vault_role_name
  vault_ca_cert_b64       = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
