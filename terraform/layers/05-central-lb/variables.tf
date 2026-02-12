
variable "service_catalog_name" {
  description = "The name of the service catalog. This should match the name in the service catalog."
  type        = string
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "network_config" {
  description = "Management/NAT network configuration for the LB cluster."
  type = object({
    gateway = string
    cidrv4  = string
    dhcp = object({
      start = string
      end   = string
    })
  })
}

variable "node_config" {
  description = "Configuration for Load Balancer nodes (resources and IP suffix)."
  type = map(object({
    ip_suffix = number
    vcpu      = number
    ram       = number
  }))
}

variable "base_image_path" {
  description = "The path to the base image for the Load Balancer nodes."
  type        = string
}

variable "allowed_subnet" {
  description = "The subnet CIDR allowed to access the management interface of the LB nodes."
  type        = string
}
