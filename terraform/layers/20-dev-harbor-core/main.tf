
# Call the Identity Module to generate AppRole & Secret ID
module "dev_harbor_identity" {
  source = "../../modules/configuration/vault-workload-identity"

  name             = var.dev_harbor_compute.cluster_identity.service_name
  vault_role_name  = local.vault_role_name
  extra_policy_hcl = <<EOT
path "secret/data/on-premise-gitlab-deployment/dev-harbor/*" {
  capabilities = ["read"]
}
EOT
}

module "dev_harbor" {
  source = "../../modules/services-docker/harbor"

  topology_config = var.dev_harbor_compute
  infra_config    = var.dev_harbor_infra
  service_domain  = local.service_domain

  vault_approle_role_id   = module.dev_harbor_identity.role_id
  vault_approle_secret_id = module.dev_harbor_identity.secret_id
  vault_ca_cert_b64       = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
  vault_address           = local.vault_address
  vault_role_name         = local.vault_role_name
}
