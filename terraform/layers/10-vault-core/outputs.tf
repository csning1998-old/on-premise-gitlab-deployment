
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

    database_roles = module.vault_pki_setup.database_roles
    ingress_roles  = module.vault_pki_setup.ingress_roles
  }
}

output "workload_identities_ingress" {
  description = "AppRole credentials for Ingress services"
  value = {
    for service_name, mod in module.vault_workload_identity_ingress : service_name => {
      role_id   = mod.approle_role_id
      role_name = mod.approle_name
      auth_path = mod.approle_path
    }
  }
}

output "workload_identities_databases" {
  description = "AppRole credentials for Database services"
  value = {
    for service_name, mod in module.vault_workload_identity_databases : service_name => {
      role_id   = mod.approle_role_id
      role_name = mod.approle_name
      auth_path = mod.approle_path
    }
  }
}

output "auth_backend_paths" {
  description = "Map of enabled Auth Backend paths"
  value       = module.vault_pki_setup.auth_backend_paths
}
