
# Get PKI CA from Vault
data "http" "vault_pki_ca" {
  url         = "https://${data.terraform_remote_state.vault_core.outputs.vault_ha_virtual_ip}:443/v1/pki/prod/ca/pem"
  ca_cert_pem = data.terraform_remote_state.vault_core.outputs.vault_ca_cert
}

# Add PKI CA to Bundle
resource "kubernetes_secret" "harbor_ca_bundle" {
  metadata {
    name      = "harbor-ca-bundle"
    namespace = "harbor"
  }

  data = {
    "ca.crt" = join("\n", [
      data.terraform_remote_state.vault_core.outputs.vault_ca_cert,
      data.http.vault_pki_ca.response_body
    ])
  }
}

# Harbor Helm Chart: https://github.com/goharbor/harbor-helm/blob/main/values.yaml
resource "helm_release" "harbor" {
  name       = "harbor"
  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = "1.18.0"
  namespace  = "harbor"
  timeout    = 600

  depends_on = [
    kubernetes_manifest.harbor_certificate,
    kubernetes_secret.harbor_ca_bundle
  ]

  values = [
    yamlencode({
      harborAdminPassword = data.vault_generic_secret.harbor_vars.data["harbor_admin_password"]

      expose = {
        type = "ingress"
        tls = {
          enabled = true
          # Specify Secret, otherwise Harbor will issue an invalid certificate
          certSource = "secret"
          secret = {
            secretName = "harbor-ingress-tls"
          }
        }
        ingress = {
          hosts = {
            core   = "harbor.iac.local"
            notary = "notary.harbor.iac.local"
          }
          className = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer"              = "vault-issuer"
            "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          }
        }
      }

      externalURL = "https://harbor.iac.local"
      # Inject CA Bundle Secret, let Harbor trust MinIO and Postgres signed certificates
      caBundleSecretName = "harbor-ca-bundle"

      persistence = {
        enabled = true
        imageChartStorage = {
          type = "s3"
          s3 = {
            region    = "us-east-1"
            bucket    = "harbor-registry"
            accesskey = data.vault_generic_secret.db_vars.data["minio_root_user"]
            secretkey = data.vault_generic_secret.db_vars.data["minio_root_password"]
            # MinIO supports TLS (not support mTLS), thus use https and port must correspond.
            regionendpoint = "https://minio.iac.local:9000"
            encrypt        = false
            secure         = true
            v4auth         = true
          }
        }
      }

      database = {
        type = "external"
        external = {
          host     = "postgres.iac.local"
          port     = "5000"
          username = "harbor"
          password = data.vault_generic_secret.harbor_vars.data["harbor_pg_db_password"]
          sslmode  = "verify-ca"
        }
      }

      redis = {
        type = "external"
        external = {
          addr     = "redis.iac.local:6379"
          password = data.vault_generic_secret.db_vars.data["redis_requirepass"]
        }
      }
    })
  ]
}
