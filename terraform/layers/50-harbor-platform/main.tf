
resource "kubernetes_namespace" "harbor" {
  metadata {
    name = "harbor"
  }
}

module "platform_trust_engine" {
  source = "../../modules/kubernetes-addons/platform-trust-engine"

  k8s_connection = {
    host    = local.k8s_api_endpoint
    ca_cert = local.k8s_cluster_ca
  }

  vault_config = {
    address   = local.vault_address
    ca_cert   = local.vault_ca_cert
    auth_path = "kubernetes"
  }

  issuer_config = {
    name             = "vault-issuer"             # The ClusterIssuer name in Microk8s
    vault_role_name  = "harbor-frontend"          # The Role name in Vault
    pki_mount_path   = local.vault_pki_path       # Adjust based on Vault PKI mount
    issue_path       = "issue"                    # or "sign", depends on Vault PKI setup
    bound_namespaces = ["cert-manager", "harbor"] # Whitelist namespaces
    token_policies   = ["harbor-pki-policy"]      # The policy created in Layer 20
  }

  reviewer_service_account = {
    name      = "vault-reviewer"
    namespace = "default"
  }

  helm_config = {
    install          = true
    version          = "v1.14.0"
    namespace        = "cert-manager"
    create_namespace = true
  }
}

# Ingress Controller
module "ingress_controller" {
  source = "../../modules/kubernetes-addons/microk8s-ingress"

  ingress_vip        = data.terraform_remote_state.microk8s_provision.outputs.harbor_microk8s_virtual_ip
  ingress_class_name = "nginx"
}

# CoreDNS Configuration
module "coredns_config" {
  source = "../../modules/kubernetes-addons/coredns-config"

  hosts = local.dns_hosts
}

# Harbor DB Initialization
module "harbor_db_init" {
  source = "../../modules/configuration/patroni-init"

  pg_host = data.terraform_remote_state.postgres.outputs.harbor_postgres_virtual_ip
  pg_port = data.terraform_remote_state.postgres.outputs.harbor_postgres_haproxy_rw_port

  pg_superuser          = "postgres"
  pg_superuser_password = data.vault_generic_secret.db_vars.data["pg_superuser_password"]

  databases = {
    "registry" = {
      owner = "harbor"
    }
  }

  users = {
    "harbor" = {
      password = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
      roles    = []
    }
  }
}
