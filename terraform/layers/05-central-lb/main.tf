
module "central_lb_cluster" {
  source = "../../modules/service-ha/load-balancer-cluster"

  topology_config = merge(
    var.load_balancer_compute,
    {
      cluster_identity = merge(
        var.load_balancer_compute.cluster_identity,
        {
          cluster_name = local.cluster_name
        }
      )
    }
  )
  infra_config     = var.load_balancer_infra
  service_segments = local.hydrated_service_segments
  service_domain   = "iac.local"
  vm_credentials   = local.vm_credentials

  network_identity = {
    nat_net_name         = local.nat_net_name
    nat_bridge_name      = local.nat_bridge_name
    hostonly_net_name    = local.hostonly_net_name
    hostonly_bridge_name = local.hostonly_bridge_name
    storage_pool_name    = local.storage_pool_name
  }
}
