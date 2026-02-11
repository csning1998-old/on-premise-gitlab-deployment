
variable "load_balancer_compute" {
  description = "Compute topology for Load Balancer service"
  type = object({
    cluster_identity = object({
      layer_number = number
      service_name = string
      component    = string
    })

    load_balancer_config = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })
}

variable "load_balancer_infra" {
  description = "Infrastructure config for Load Balancer service"
  type = object({
    network = object({
      nat = object({
        gateway = string
        cidrv4  = string
        dhcp = optional(object({
          start = string
          end   = string
        }))
      })
      hostonly = object({
        gateway = string
        cidrv4  = string
      })
    })
    allowed_subnet = string
  })
}

variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}
