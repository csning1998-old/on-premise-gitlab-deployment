
variable "topology_config" {
  description = "Standardized compute topology configuration for Load Balancer HA Cluster."
  type = object({
    cluster_identity = object({
      service_name = string
      component    = string
      cluster_name = string
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

  # At least one Load Balancer Class node
  validation {
    condition     = length(var.topology_config.load_balancer_config.nodes) > 0
    error_message = "High Availability architecture requires at least one Load Balancer Class node."
  }

  # Load Balancer Node specification (vCPU >= 2, RAM >= 1024)
  validation {
    condition = alltrue([
      for k, node in var.topology_config.load_balancer_config.nodes :
      node.vcpu >= 2 && node.ram >= 1024
    ])
    error_message = "Load Balancer nodes require at least 2 vCPUs and 1024MB RAM."
  }
}

variable "infra_config" {
  description = "Standardized infrastructure network configuration."
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

  # Network CIDR validation
  validation {
    condition = alltrue([
      can(cidrnetmask(var.infra_config.network.nat.cidrv4)),
      can(cidrnetmask(var.infra_config.network.hostonly.cidrv4)),
      can(cidrnetmask(var.infra_config.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "service_domain" {
  description = "The FQDN for the Load Balancer service"
  type        = string
}

# Network Identity for Naming Policy
variable "network_identity" {
  description = "Pre-calculated network and bridge names passed from Layer"
  type = object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
    storage_pool_name    = string
  })
}

variable "service_segments" {
  description = "Topology Definition: List of all network segments the LB must connect to."
  type = list(object({
    name        = string
    bridge_name = string
    cidr        = string
    vrid        = number
    vip         = string
    node_ips    = map(string) # Map of "node_name" => "ip"
  }))
}

# Credentials Injection
variable "vm_credentials" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}

variable "vault_agent_config" {
  description = "Vault Agent Configuration"
  sensitive   = true
  type = object({
    role_id     = string
    secret_id   = string
    ca_cert_b64 = string
    role_name   = string # PKI Role Name
  })
}
