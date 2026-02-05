
# This file defines the single, data-driven build block.

packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["source.qemu.ubuntu"]

  # Common Provisioners
provisioner "shell" {
    inline = [
      # Waiting for cloud-init to finish
      "/usr/bin/cloud-init status --wait",

      # Restoring online repositories
      "sudo rm -f /etc/apt/sources.list.d/ubuntu.sources",
      "echo 'deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse' | sudo tee /etc/apt/sources.list",
      "echo 'deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse' | sudo tee -a /etc/apt/sources.list",
      "echo 'deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse' | sudo tee -a /etc/apt/sources.list",
      "echo 'deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse' | sudo tee -a /etc/apt/sources.list",

      # Performing full system upgrade
      "sudo apt-get update",
      "sudo apt-get dist-upgrade -y",
      "sudo apt-get autoremove -y",
      "sudo apt-get clean"
    ]
    execute_command = "echo '${local.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
  }

  provisioner "ansible" {
    playbook_file       = "../ansible/playbooks/00-provision-base-image.yaml"
    inventory_directory = "../ansible/"
    user                = local.ssh_username

    # Ansible group is dynamically set by a variable.
    groups = [
      var.build_spec.suffix
    ]
    ansible_env_vars = [
      "ANSIBLE_CONFIG=../ansible.cfg"
    ]
    extra_arguments = [
      "--extra-vars", "expected_hostname=${local.final_vm_name}",
      "--extra-vars", "public_key_file=${local.ssh_public_key_path}",
      "--extra-vars", "ssh_user=${local.ssh_username}",
      "--extra-vars", "ansible_ssh_transfer_method=piped",
      "-v",
    ]
  }
}