
/**
 * Given the changes announced in bitnami/containers#83267, most of the new and hardened image versions 
 * require a Bitnami Secure Images subscription such that the official Harbor Helm Chart is used instead.
 */

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
      harborAdminPassword = local.harbor_admin_password

      expose = {
        type = "ingress"
        tls = {
          enabled = true
          # Specify Secret, otherwise Harbor will issue an invalid certificate
          certSource = "secret"
          secret = {
            secretName = "harbor-ingress-cert"
          }
        }
        ingress = {
          hosts = {
            core   = var.harbor_hostname
            notary = "notary.${var.harbor_hostname}"
          }
          className = "nginx"
          annotations = {
            "nginx.ingress.kubernetes.io/proxy-body-size" = "0"
          }
        }
      }

      externalURL = "https://${var.harbor_hostname}"
      # Inject CA Bundle Secret, let Harbor trust MinIO and Postgres signed certificates
      caBundleSecretName = "harbor-ca-bundle"

      persistence = {
        enabled = true
        imageChartStorage = {
          type            = "s3"
          disableredirect = true
          s3 = {
            region    = "us-east-1"
            bucket    = "harbor-registry"
            accesskey = local.minio_access_key
            secretkey = local.minio_secret_key
            # MinIO supports TLS (not support mTLS), thus use https and port must correspond.
            regionendpoint = local.minio_address
            forcePathStyle = true
            secure         = true
            v4auth         = true
            encrypt        = false
          }
        }
      }

      database = {
        type = "external"
        external = {
          host     = local.postgres_address
          port     = "5000"
          username = "harbor"
          password = local.harbor_pg_password
          sslmode  = "verify-ca"
        }
      }

      # Set `enable_tls = false` to disable TLS for Redis in `terraform/layers/20-harbor-redis/main.tf`
      redis = {
        type = "external"
        external = {
          addr     = local.redis_address
          password = local.redis_password

          tlsOptions = {
            enable = true
          }
        }
      }
    })
  ]
}
