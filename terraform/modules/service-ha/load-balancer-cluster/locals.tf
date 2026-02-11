
locals {
  # Ansible execution path
  ansible_root_path = abspath("${path.root}/../../../ansible")

  # Gateway IP prefix extraction
  nat_network_subnet_prefix = join(".", slice(split(".", var.infra_config.network.nat.gateway), 0, 3))

  # Image Injection Logic: Inject Load Balancer Base Image Path
  load_balancer_nodes_with_img = {
    for k, v in var.topology_config.load_balancer_config.nodes : k => merge(v, {
      base_image_path = var.topology_config.load_balancer_config.base_image_path
    })
  }

  # Merge all
  all_nodes_map = merge(
    local.load_balancer_nodes_with_img,
  )
}
