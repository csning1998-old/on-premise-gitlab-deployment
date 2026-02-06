
locals {
  # Define the absolute path for TLS directory.
  layer_tls_dir = abspath("${path.root}/tls")
}

locals {
  root_domain = var.service_topology.root_domain

  # Calculate Database Roles (Flatten Logic)
  # Logic: Iterate over all Platform x Database Types
  db_roles_flat = merge([
    for db_type, config in var.service_topology.database_services.types : {
      for platform in var.service_topology.platforms : "${platform}-${db_type}" => {
        name = "${platform}-${db_type}-role"

        # Combine domains: prefix.platform.root_domain + platform.root_domain
        allowed_domains = concat(
          [for p in config.prefixes : "${p}.${platform}.${local.root_domain}"],
          ["${platform}.${local.root_domain}"]
        )

        max_ttl = var.service_topology.database_services.max_ttl
        ttl     = var.service_topology.database_services.ttl
      }
    }
  ]...)

  # Calculate Ingress Roles
  ingress_roles_final = {
    for name, config in var.service_topology.ingress_services : "${name}-ingress" => {
      name = "${name}-ingress-role"

      # Combine domains: subdomain.root_domain
      allowed_domains = [for s in config.subdomains : "${s}.${local.root_domain}"]

      max_ttl = coalesce(config.max_ttl, 60 * 60 * 24 * 90)
      ttl     = coalesce(config.ttl, 60 * 60 * 24)
    }
  }
}
