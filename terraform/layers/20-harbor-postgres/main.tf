
# Call the Identity Module to generate AppRole & Secret ID
module "postgres_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name            = var.harbor_postgres_compute.cluster_identity.service_name
  vault_role_name = local.vault_role_name
}

module "postgres_harbor" {
  source = "../../modules/service-ha/patroni-cluster"

  topology_config = var.harbor_postgres_compute
  infra_config    = var.harbor_postgres_infra
  service_domain  = local.service_domain

  vault_role_name         = local.vault_role_name
  vault_approle_role_id   = module.postgres_identity.role_id
  vault_approle_secret_id = module.postgres_identity.secret_id
  vault_ca_cert_b64       = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}
