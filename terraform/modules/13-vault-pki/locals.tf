
locals {
  root_domain = var.root_domain

  platforms = toset(["gitlab", "harbor"])

  postgres_domains = [
    for p in local.platforms : "pg.${p}.${local.root_domain}"
  ]

  redis_domains = [
    for p in local.platforms : "redis.${p}.${local.root_domain}"
  ]

  minio_domains = flatten([
    for p in local.platforms : [
      "s3.${p}.${local.root_domain}",     # API (9000)
      "console.${p}.${local.root_domain}" # Web UI (9001)
    ]
  ])

  harbor_ingress_domains = [
    "harbor.${local.root_domain}",
    "notary.harbor.${local.root_domain}",
  ]

  gitlab_ingress_domains = [
    "gitlab.${local.root_domain}",
    "registry.gitlab.${local.root_domain}",
    "kas.gitlab.${local.root_domain}"
  ]
}
