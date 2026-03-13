
# This file defines the variables for building the 'base-apt-updated' image.
# This image serves as the backing layer for all other service images.
build_spec = {
  suffix   = "00-base-apt-updated"
  vnc_port = 5990
}

os_spec = {
  vm_name      = "ubuntu-server-24"
  iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
  iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
}
