
locals {
  kubeconfig_raw = data.terraform_remote_state.gitlab_cluster.outputs.kubeconfig_content
  kubeconfig     = yamldecode(local.kubeconfig_raw)

  cluster_info = local.kubeconfig.clusters[0].cluster
  user_info    = local.kubeconfig.users[0].user

  s3_endpoint = data.vault_generic_secret.s3_artifacts.data["endpoint"]
  s3_region   = "us-east-1"
}
