
variable "vault_addr" {
  description = "The address of the Vault server"
  type        = string
}

variable "ca_cert_file" {
  description = "Path to the Root CA certificate file for the Vault Provider verification"
  type        = string
}
