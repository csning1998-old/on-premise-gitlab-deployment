
module "vault_compute" {
  source = "../../modules/11-vault-ha"

  vault_compute = var.vault_compute
  vault_infra   = var.vault_infra

  tls_source_dir = module.vault_tls.tls_source_dir
}

module "vault_tls" {
  source = "../../modules/12-vault-tls"

  vault_virtual_ip_sans = var.vault_compute.ha_config.virtual_ip
}

module "vault_pki_config" {
  source = "../../modules/13-vault-pki"

  depends_on = [module.vault_compute]

  vault_addr   = "https://${var.vault_compute.ha_config.virtual_ip}:8200"
  ca_cert_file = module.vault_tls.ca_cert_file
}
