
module "minio_harbor" {
  source = "../../modules/27-minio-ha"

  topology_config = var.harbor_minio_compute
  infra_config    = var.harbor_minio_infra

  vault_role_name   = "harbor-minio"
  vault_ca_cert_b64 = filebase64("${path.root}/../10-vault-core/tls/vault-ca.crt")
}

module "minio_harbor_config" {
  source     = "../../modules/28-minio-config"
  depends_on = [module.minio_harbor]

  minio_tenants            = var.harbor_minio_tenants
  vault_secret_path_prefix = "secret/on-premise-gitlab-deployment/harbor/s3_credentials"
  minio_server_url         = "https://${var.harbor_minio_compute.ha_config.virtual_ip}:9000"
}
