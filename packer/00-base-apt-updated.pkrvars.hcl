
# This file defines the variables for building the 'base-apt-updated' image.
# This image serves as the backing layer for all other service images.
build_spec = {
  suffix   = "00-base-apt-updated"
  vnc_port = 5990
}
