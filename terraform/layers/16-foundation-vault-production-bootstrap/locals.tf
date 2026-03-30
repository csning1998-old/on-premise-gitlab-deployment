
# State Object
locals {
  state = {
    metadata           = data.terraform_remote_state.metadata.outputs
    vault_sys          = data.terraform_remote_state.vault_sys.outputs
    vault_bootstrapper = data.terraform_remote_state.vault_bootstrapper.outputs # Seed Vault is in Layer 00
  }

  sys_vault_addr = "https://${local.state.vault_sys.service_vip}:443"
  ca_cert_path   = local.state.vault_sys.ca_cert_path
}
