
module "postgres_ha" {
  source = "../../modules/21-composition-postgres-ha"

  service_name            = "harbor"
  postgres_cluster_config = var.postgres_cluster_config
  postgres_infrastructure = var.postgres_infrastructure
  inventory_file          = "inventory-postgres-harbor.yaml"
}
