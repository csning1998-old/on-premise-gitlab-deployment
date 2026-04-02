
# K8s Infrastructure Secrets
resource "kubernetes_secret" "gitlab_postgres_tls" {
  metadata {
    name      = "gitlab-postgres-tls"
    namespace = var.gitlab_helm_config.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = base64decode(jsondecode(data.vault_kv_secret_v2.gitlab_db.data_json)["tls"]["crt"])
    "tls.key" = base64decode(jsondecode(data.vault_kv_secret_v2.gitlab_db.data_json)["tls"]["key"])
    "ca.crt"  = base64decode(jsondecode(data.vault_kv_secret_v2.gitlab_db.data_json)["tls"]["ca"])
  }
}
