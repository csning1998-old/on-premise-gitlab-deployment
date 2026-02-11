locals {
  # 1. Basic Settings: VIP and LB Node IP Offset Rules
  default_vip_hostnum   = 250 # Default VIP is .250
  lb_node_start_hostnum = 251 # LB Node IP starts from .251 (e.g., .251, .252)

  # 2. Source of Truth
  service_segments = {
    "gitlab-frontend" = {
      bridge_name = "br-gitlab-front",
      cidr        = "172.16.134.0/24",
      vrid        = 134
    },
    "harbor-frontend" = {
      bridge_name = "br-harbor-front",
      cidr        = "172.16.135.0/24",
      vrid        = 135
    },
    "vault" = {
      bridge_name = "br-vault",
      cidr        = "172.16.136.0/24",
      vrid        = 136
    },
    "harbor-postgres" = {
      bridge_name = "br-harbor-pg",
      cidr        = "172.16.137.0/24",
      vrid        = 137
    },
    "harbor-redis" = {
      bridge_name = "br-harbor-redis",
      cidr        = "172.16.138.0/24",
      vrid        = 138
    },
    "harbor-minio" = {
      bridge_name = "br-harbor-minio",
      cidr        = "172.16.139.0/24",
      vrid        = 139
    },
    "gitlab-postgres" = {
      bridge_name = "br-gitlab-pg",
      cidr        = "172.16.140.0/24",
      vrid        = 140
    },
    "gitlab-redis" = {
      bridge_name = "br-gitlab-redis",
      cidr        = "172.16.141.0/24",
      vrid        = 141
    },
    "gitlab-minio" = {
      bridge_name = "br-gitlab-minio",
      cidr        = "172.16.142.0/24",
      vrid        = 142
    },
    "dev-harbor" = {
      bridge_name = "br-dev-harbor",
      cidr        = "172.16.143.0/24",
      vrid        = 143
    }
  }
}
locals {
  # Hydration: Convert Map to List and fill in calculated IPs
  hydrated_service_segments = [
    for seg_key, seg_conf in local.service_segments : {
      name        = seg_key
      bridge_name = seg_conf.bridge_name
      cidr        = seg_conf.cidr
      vrid        = seg_conf.vrid

      # Auto-calculate VIP: CIDR + .250
      vip = cidrhost(seg_conf.cidr, local.default_vip_hostnum)

      # Auto-calculate Node IPs: CIDR + (.251 + index)
      # e.g. Output: { "lb-node-00" = "172.16.134.251", "lb-node-01" = "172.16.134.252" }
      node_ips = {
        for node_key, node_conf in var.load_balancer_compute.load_balancer_config.nodes :
        node_key => cidrhost(
          seg_conf.cidr,
          local.lb_node_start_hostnum + index(keys(var.load_balancer_compute.load_balancer_config.nodes), node_key)
        )
      }
    }
  ]
}

locals {
  # Network Identity (Standard Libvirt Naming)
  svc_name     = var.load_balancer_compute.cluster_identity.service_name
  comp_name    = var.load_balancer_compute.cluster_identity.component
  layer_number = var.load_balancer_compute.cluster_identity.layer_number
  cluster_name = "${local.layer_number}-${local.svc_name}-${local.comp_name}"

  nat_net_name      = "iac-${local.svc_name}-${local.comp_name}-nat"
  hostonly_net_name = "iac-${local.svc_name}-${local.comp_name}-hostonly"
  storage_pool_name = "iac-${local.svc_name}-${local.comp_name}"

  # Bridge Naming for Mgmt/Hostonly
  svc_abbr             = substr(local.svc_name, 0, 3)  # loa
  comp_abbr            = substr(local.comp_name, 0, 3) # cor
  nat_bridge_name      = "iac-mgmt-br"                 # Management Bridge
  hostonly_bridge_name = "iac-internal-br"
}

locals {
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    password             = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path  = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
}
