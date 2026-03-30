
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.5.0"
    }
  }
}

# The target Vault being configured (Bootstrapper/Initial Vault)
provider "vault" {
  address          = var.vault_dev_addr
  ca_cert_file     = var.ca_cert_file
  skip_tls_verify  = true # Temporarily skip verification if IP SANs are missing in bootstrapper cert
}
