
variable "vault_dev_addr" {
  description = "The address of the bootstrap dev Vault"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "vault_root_token" {
  description = "Initial root token for bootstrapping the target Vault cluster"
  type        = string
  sensitive   = true
}

variable "ca_cert_file" {
  description = "Path to the CA certificate file"
  type        = string
}
