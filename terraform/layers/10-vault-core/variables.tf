
variable "tls_mode" {
  description = "TLS generation mode: 'generated' (Terraform creates keys via tls provider) or 'manual' (Terraform assumes files exist and does nothing)."
  type        = string
}

variable "vault_compute" {
  description = "Compute topology for Vault Core service"
  type = object({

    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
    })

    # Vault Server Nodes (Map)
    vault_cluster = object({
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })

    haproxy_config = object({
      virtual_ip = string

      # Vault uses HAProxy as entry point
      nodes = map(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      base_image_path = string
    })
  })
}

variable "vault_infra" {
  description = "Infrastructure config for Vault Core service"
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

variable "service_topology" {
  description = "High-level definition of platforms and services"

  type = object({
    root_domain = string
    platforms   = list(string) # e.g. ["gitlab", "harbor"]

    # Define database services and their URL prefixes
    database_services = object({
      types = map(object({
        prefixes = list(string)
      }))
      max_ttl = number
      ttl     = number
    })

    # Define ingress services and their subdomains
    ingress_services = map(object({
      subdomains = list(string)
      max_ttl    = optional(number)
      ttl        = optional(number)
    }))
  })
}

variable "vault_auth_backends" {
  description = "Map of Auth Backends to enable (e.g., approle, kubernetes)"
  type = map(object({
    type = string
    path = string
  }))
}

variable "vault_pki_engine_config" {
  description = "Configuration for the PKI Secrets Engine"
  type = object({
    path                = string
    root_ca_common_name = string

    default_lease_ttl_seconds = number
    max_lease_ttl_seconds     = number
  })
}
