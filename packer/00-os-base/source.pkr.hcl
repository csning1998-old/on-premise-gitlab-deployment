
# This file defines the single, data-driven QEMU source for ISO-based installation.

locals {
  ssh_username        = vault("secret/data/on-premise-gitlab-deployment/variables", "ssh_username")
  ssh_password        = vault("secret/data/on-premise-gitlab-deployment/variables", "ssh_password")
  ssh_password_hash   = vault("secret/data/on-premise-gitlab-deployment/variables", "ssh_password_hash")

  # The final hostname is dynamically composed from variables.
  final_hostname = "${var.common_spec.vm_name}-${var.build_spec.suffix}"
  final_vm_name = "${local.final_hostname}.qcow2"
}

source "qemu" "ubuntu" {
  # Dynamic Settings from Variables
  vm_name          = local.final_vm_name
  output_directory = "../output/${var.build_spec.suffix}"
  vnc_port_min     = var.build_spec.vnc_port
  vnc_port_max     = var.build_spec.vnc_port

  # Common Settings from Variables
  iso_url      = var.common_spec.iso_url
  iso_checksum = var.common_spec.iso_checksum
  cpus         = var.common_spec.cpus
  memory       = var.common_spec.memory
  disk_size    = var.common_spec.disk_size

  # Common Hardcoded Settings
  disk_interface = "virtio"
  net_bridge     = var.net_bridge
  net_device     = var.net_device
  accelerator    = "kvm"
  qemu_binary    = "/usr/bin/qemu-system-x86_64"
  qemuargs       = [["-cpu", "host"]]
  headless       = true
  format         = "qcow2"

  # Cloud-Init & Autoinstall
  http_directory = "../http"
  cd_content = {
    "/user-data" = templatefile("${path.root}/../http/user-data", {
      hostname      = local.final_hostname
      username      = local.ssh_username
      password_hash = local.ssh_password_hash
    })
    "/meta-data" = "instance-id: ${local.final_hostname}\nlocal-hostname: ${local.final_hostname}"
  }
  cd_label = "cidata"

  # Boot & SSH
  boot_wait = "5s"
  boot_command = [
    "<wait2s>", "e<wait>", "<down><down><down><end>",
    " autoinstall ds=nocloud;", "<f10>"
  ]

  ssh_username     = local.ssh_username
  ssh_password     = local.ssh_password
  ssh_timeout      = "10m"
  shutdown_command = "sudo shutdown -P now"
}
