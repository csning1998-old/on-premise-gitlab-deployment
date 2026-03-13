
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
    execute_command = "echo '${local.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"

    inline = [
      # Waiting for cloud-init to finish (Only needed if we just installed)
      local.is_base_layer ? "/usr/bin/cloud-init status --wait" : "echo 'Skipping cloud-init wait'",

      # Dynamically fetch the Ubuntu codename (e.g., noble, jammy, focal)
      "UBUNTU_CODENAME=$(lsb_release -cs)",
      "echo \"Detected Ubuntu Codename: $UBUNTU_CODENAME\"",

      # Restoring online repositories (Only needed once in base)
      local.is_base_layer ? "rm -f /etc/apt/sources.list.d/ubuntu.sources" : "echo 'Skipping repo restoration'",

      # Use Shell variable $UBUNTU_CODENAME to replace Packer variable
      local.is_base_layer ? "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME} main restricted universe multiverse\" | tee /etc/apt/sources.list" : "echo 'Skipping source.list update'",
      local.is_base_layer ? "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-updates main restricted universe multiverse\" | tee -a /etc/apt/sources.list" : "true",
      local.is_base_layer ? "echo \"deb http://archive.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-backports main restricted universe multiverse\" | tee -a /etc/apt/sources.list" : "true",
      local.is_base_layer ? "echo \"deb http://security.ubuntu.com/ubuntu $${UBUNTU_CODENAME}-security main restricted universe multiverse\" | tee -a /etc/apt/sources.list" : "true",

      # Performing full system upgrade (ONLY for base layer)
      "apt-get update",
      local.is_base_layer ? "apt-get dist-upgrade -y" : "echo 'Skipping dist-upgrade'",
      local.is_base_layer ? "apt-get autoremove -y" : "true",
      local.is_base_layer ? "apt-get clean" : "true",

      "apt-get install -y openssh-sftp-server",
      "systemctl restart ssh"
    ]
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
      "--extra-vars", "expected_hostname=${local.final_hostname}",
      "--extra-vars", "public_key_file=${local.ssh_public_key_path}",
      "--extra-vars", "ssh_user=${local.ssh_username}",
      "--extra-vars", "ansible_ssh_transfer_method=piped",
      "-v",
    ]
  }
}