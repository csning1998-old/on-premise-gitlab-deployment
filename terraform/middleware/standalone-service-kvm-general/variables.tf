
variable "cluster_name" {
  description = "The unique name of the cluster"
  type        = string
}

variable "component_name" {
  description = "The name of the component (matches HA map keys)"
  type        = string
}

variable "node_suffix" {
  description = "The suffix for the single node (matches HA nodes map keys)"
  type        = string
}

variable "topology_node" {
  description = "Standardized compute topology for a standalone node."
  type = object({
    storage_pool_name = string

    base_image_path = string
    role            = string
    network_tier    = optional(string, "default")

    ip_suffix = number
    vcpu      = number
    ram       = number
    data_disks = optional(list(object({
      name_suffix = string
      capacity    = number
    })), [])
  })
}

variable "network_parameters" {
  description = "Map of L3 network configurations keyed by tier name."
  type = map(object({
    network = object({
      nat = object({
        gateway = string,
        cidrv4  = string,
        dhcp    = optional(any)
      })
      hostonly = object({
        gateway = string,
        cidrv4  = string
      })
    })
    network_access_scope = string
  }))

  validation {
    condition = alltrue(flatten([
      for k, v in var.network_parameters : [
        can(cidrnetmask(v.network.nat.cidrv4)),
        can(cidrnetmask(v.network.hostonly.cidrv4)),
        can(cidrnetmask(v.network_access_scope))
      ]
    ]))
    error_message = "All network CIDRs must be valid IPv4 CIDR ranges."
  }
}

variable "network_bindings" {
  description = "Map of L2 network bindings keyed by tier name."
  type = map(object({
    nat_net_name         = string
    nat_bridge_name      = string
    hostonly_net_name    = string
    hostonly_bridge_name = string
  }))
}

# Generic Ansible Injections
variable "ansible_inventory_content" {
  description = "The fully rendered Ansible inventory string. Handled by the caller layer."
  type        = string
}

variable "ansible_extra_vars" {
  description = "A generic map of extra variables to pass to the ansible-runner module. Handled by the caller layer."
  type        = any
}

variable "ansible_playbook_file" {
  description = "The name of the Ansible playbook file to execute."
  type        = string
}

# System Credentials
variable "credentials_system" {
  description = "System level credentials (ssh user, password, keys)"
  sensitive   = true
  type = object({
    username             = string
    password             = string
    ssh_public_key_path  = string
    ssh_private_key_path = string
  })
}
