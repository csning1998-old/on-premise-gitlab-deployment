
variable "cluster_name" {
  description = "The unique name of the cluster (e.g. gitlab-core)"
  type        = string
}

variable "topology_config" {
  description = "Map of component configurations (postgres, etcd) containing distinct network, storage, and node specs."
  type = map(object({

    storage_pool_name = string

    nodes_configuration = map(object({
      ip              = string
      vcpu            = number
      ram             = number
      base_image_path = string
      role            = string
    }))
  }))

  # 1. Etcd Raft Quorum Check
  validation {
    condition     = length(var.topology_config["etcd"].nodes_configuration) % 2 != 0
    error_message = "Etcd node count must be an odd number (1, 3, 5, etc.) to ensure a stable Raft quorum."
  }

  # 2. Postgres Data Node Specification Check
  validation {
    condition = alltrue([
      for k, node in var.topology_config["postgres"].nodes_configuration :
      node.vcpu >= 2 && node.ram >= 2048
    ])
    error_message = "Postgres data nodes require at least 2 vCPUs and 2048MB RAM."
  }

  # 3. Etcd Node Specification Check
  validation {
    condition = alltrue([
      for k, node in var.topology_config["etcd"].nodes_configuration :
      node.vcpu >= 1 && node.ram >= 1024
    ])
    error_message = "Etcd nodes require at least 1 vCPU and 1024MB RAM."
  }
}

variable "service_vip" {
  type = string
}

variable "service_domain" {
  description = "The FQDN for the Load Balancer service"
  type        = string
}

# Network Identity for Naming Policy
variable "network_identity" {
  description = "Pre-calculated network and bridge names passed from Layer"
  type = map(object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
  }))
}

variable "network_config" {
  description = "Network Config for Hypervisor (Gateways/CIDRs)"
  type = map(object({
    network = object({
      nat = object({
        gateway = string
        cidrv4  = string
        dhcp    = optional(object({ start = string, end = string }))
      })
      hostonly = object({
        gateway = string
        cidrv4  = string
      })
    })
    allowed_subnet = string
  }))

  # Network CIDR validation
  validation {
    condition = alltrue([
      for k, v in var.network_config :
      can(cidrnetmask(v.network.nat.cidrv4)) &&
      can(cidrnetmask(v.network.hostonly.cidrv4)) &&
      can(cidrnetmask(v.allowed_subnet))
    ])
    error_message = "All network CIDRs must be valid."
  }
}

variable "pki_artifacts" {
  description = "PKI certificates passed from Layer 00 via Layer 30"
  type        = any
  default     = null
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

variable "db_credentials" {
  description = "Database level credentials (patroni, replication)"
  sensitive   = true
  type = object({
    superuser_password   = string
    replication_password = string
    vrrp_secret          = string
  })
}

variable "vault_agent_config" {
  description = "Vault Agent Configuration"
  sensitive   = true
  type = object({
    role_id       = string
    secret_id     = string
    ca_cert_b64   = string
    role_name     = string # PKI Role Name
    vault_address = string
  })
}
