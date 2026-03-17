
variable "vault_dev_addr" {
  description = "The address of the Vault server"
  type        = string
  default     = "https://127.0.0.1:8200"
}

variable "vault_config" {
  description = "Compute topology for Vault Core service."
  type = map(object({
    role            = string
    network_tier    = string
    base_image_path = string

    nodes = map(object({
      ip_suffix            = number
      vcpu                 = number
      ram_size             = number
      os_disk_capacity_gib = optional(number)
    }))
  }))
}

variable "ansible_files" {
  description = "Meta configuration of Ansible inventory for Vault Core service."
  type = object({
    playbook_file           = string
    inventory_template_file = string
  })
}
