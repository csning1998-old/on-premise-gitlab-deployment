
variable "vault_virtual_ip_sans" {
  description = "HA Virtual IP of Vault Core service used for SANs"
  type        = string
}

variable "output_dir" {
  description = "The absolute path where the generated certificates should be saved."
  type        = string
}
