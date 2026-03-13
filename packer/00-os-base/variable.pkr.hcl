
# This file defines all variables for the data-driven Packer build.

# Build Control Variables 

variable "build_spec" {
  type = object({
    suffix   = string
    vnc_port = number
  })
  description = "Defines the specific parameters for this build type."
}

# Common Variables, from *.pkrvars.hcl or command line

variable "common_spec" {
  type = object({
    cpus         = number
    memory       = number
    disk_size    = number
  })
  description = "Defines common hardware parameters shareable across any OS."
}

variable "os_spec" {
  type = object({
    vm_name      = string
    iso_url      = string
    iso_checksum = string
  })
  description = "Defines OS-specific metadata (ISO, default hostname)."
}

variable "net_bridge" {
  type    = string
  default = "virbr0"
}

variable "net_device" {
  type    = string
  default = "virtio-net"
}