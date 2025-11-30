
variable "vault_cluster" {
  description = "Vault Cluster (used for SANs)"
  type = object({
    nodes = map(object({
      ip = string
    }))
    ha_config = object({
      virtual_ip = string
    })
  })
}

variable "output_dir" {
  description = "The absolute path where the generated certificates should be saved."
  type        = string
}
