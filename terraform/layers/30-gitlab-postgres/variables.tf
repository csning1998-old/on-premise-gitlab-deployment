
variable "service_catalog_name" {
  description = "The unique service name defined in Layer 00 (e.g. 'vault'). Used to lookup SSoT properties."
  type        = string
}

variable "service_dependencies" {
  description = "List of dependency components to provision (e.g. ['postgres', 'etcd'])."
  type        = list(string)
  default     = ["postgres", "etcd"]
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "gitlab_postgres_config" {
  description = "Compute topology for Gitlab Postgres service"
  type = object({
    # Postgres Data Nodes (Map)
    postgres_config = object({
      nodes = map(object({
        ip_suffix = number
        vcpu      = number
        ram       = number
      }))
      base_image_path = string
    })

    # Postgres Etcd Nodes (Map)
    etcd_config = object({
      nodes = map(object({
        ip_suffix = number
        vcpu      = number
        ram       = number
      }))
      base_image_path = string
    })
  })
}
