
# This file defines the build block for the Services layer.

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

  # Basic connectivity check
  provisioner "shell" {
    execute_command = "echo '${local.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    inline = [
      "echo 'Skipping heavy OS updates in service layer'",
      "apt-get update",
      "apt-get install -y openssh-sftp-server",
      "systemctl restart ssh"
    ]
  }

  # Ansible Service Provisioner
  provisioner "ansible" {
    playbook_file       = "../../ansible/playbooks/00-provision-base-image.yaml"
    inventory_directory = "../../ansible/"
    user                = local.ssh_username
    groups              = [var.build_name]
    
    ansible_env_vars = [
      "ANSIBLE_CONFIG=../../ansible.cfg"
    ]
    extra_arguments = [
      "--extra-vars", "expected_hostname=${local.final_hostname}",
      "--extra-vars", "public_key_file=${vault("secret/data/on-premise-gitlab-deployment/variables", "ssh_public_key_path")}",
      "--extra-vars", "ssh_user=${local.ssh_username}",
      "--extra-vars", "ansible_ssh_transfer_method=piped",
      "-v",
    ]
  }

  # Generate SHA256 checksum for the artifact
  post-processor "shell-local" {
    inline = [
      "echo 'Generating SHA256 checksum for ${local.final_vm_name}...'",
      "cd ../output/${var.build_name} && sha256sum ${local.final_vm_name} > ${local.final_vm_name}.sha256",
      "echo 'Checksum generated at ../output/${var.build_name}/${local.final_vm_name}.sha256'"
    ]
  }
}
