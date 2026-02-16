
variable "service_catalog_name" {
  description = "The unique service name defined in Layer 00 (e.g. 'vault'). Used to lookup SSoT properties."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "vault_config" {
  description = "Compute topology for Vault Core service."
  type = object({
    nodes = map(object({
      ip_suffix = number
      vcpu      = number
      ram       = number
    }))
    base_image_path = string
  })
}

variable "tls_mode" {
  description = "TLS generation mode: 'generated' (Terraform creates keys via tls provider) or 'manual' (Terraform assumes files exist and does nothing)."
  type        = string
}
