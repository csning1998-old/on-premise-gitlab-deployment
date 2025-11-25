# Registry Server Topology & Configuration

variable "minio_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      minio = list(object({
        ip   = string
        vcpu = number
        ram  = number
        data_disks = list(object({
          name_suffix = string
          capacity    = number
        }))
      }))
    })
    base_image_path = optional(string, "../../../packer/output/06-base-minio/ubuntu-server-24-06-base-minio.qcow2")
  })

  # Rule 1: Node Count (1, 4, 8)
  validation {
    condition     = length(var.minio_cluster_config.nodes.minio) == 1 || (length(var.minio_cluster_config.nodes.minio) >= 4 && length(var.minio_cluster_config.nodes.minio) <= 8 && length(var.minio_cluster_config.nodes.minio) % 4 == 0)
    error_message = "MinIO cluster size must be exactly 1 node, or between 4 and 8 nodes (inclusive) and be a multiple of 4."
  }

  # Rule 2: Data Disks (> 0 for all nodes)
  validation {
    condition     = alltrue([for node in var.minio_cluster_config.nodes.minio : length(node.data_disks) > 0])
    error_message = "Each MinIO node must have at least one data disk configured."
  }
}

# Registry Server Infrastructure Network Configuration

variable "minio_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the MinIO Service."
  type = object({
    network = object({
      nat = object({
        name_network = string
        name_bridge  = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = string
            end   = string
          }))
        })
      })
      hostonly = object({
        name_network = string
        name_bridge  = string
        ips = object({
          address = string
          prefix  = number
          dhcp = optional(object({
            start = string
            end   = string
          }))
        })
      })
    })
    minio_allowed_subnet = optional(string, "172.16.138.0/24")
    storage_pool_name    = optional(string, "iac-minio")
  })
}
