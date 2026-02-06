
output "vault_ha_virtual_ip" {
  description = "The VIP of the Vault HA Cluster"
  value       = var.vault_compute.haproxy_config.virtual_ip
}

output "vault_cartificates" {
  description = "The Certificates content of the Vault Cluster"
  value = {
    root_ca = module.vault_pki_setup.pki_root_ca_certificate
    ca_cert = module.vault_tls_gen.ca_cert_pem # for PKI
  }
}

output "pki_configuration" {
  description = "PKI Configuration Summary"
  value = {
    path = module.vault_pki_setup.vault_pki_path

    roles = {
      postgres   = module.vault_pki_setup.postgres_role_names
      redis      = module.vault_pki_setup.redis_role_names
      minio      = module.vault_pki_setup.minio_role_names
      dev_harbor = module.vault_pki_setup.ingress_role_names["dev-harbor-ingress"]
      harbor     = module.vault_pki_setup.ingress_role_names["harbor-ingress"]
      gitlab     = module.vault_pki_setup.ingress_role_names["gitlab-ingress"]
    }

    domains = {
      postgres   = module.vault_pki_setup.postgres_role_domains
      redis      = module.vault_pki_setup.redis_role_domains
      minio      = module.vault_pki_setup.minio_role_domains
      dev_harbor = module.vault_pki_setup.ingress_role_domains["dev-harbor-ingress"]
      harbor     = module.vault_pki_setup.ingress_role_domains["harbor-ingress"]
      gitlab     = module.vault_pki_setup.ingress_role_domains["gitlab-ingress"]
    }
  }
}
