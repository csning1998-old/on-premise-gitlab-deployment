build_spec = {
  suffix   = "10-base-etcd"
  vnc_port = 5999
}

os_spec = {
  vm_name = "ubuntu-server-24"
}

source_image = "../output/00-base-apt-updated/ubuntu-server-24-00-base-apt-updated.qcow2"
