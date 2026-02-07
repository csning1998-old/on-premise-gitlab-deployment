
# Declare Harbor certificate (K8s resource)
resource "kubernetes_manifest" "harbor_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.harbor_helm_config.tls_secret_name
      namespace = var.harbor_helm_config.namespace
    }
    spec = {
      secretName = var.harbor_helm_config.tls_secret_name
      issuerRef = {
        name = local.issuer_name
        kind = local.issuer_kind
      }
      commonName  = local.harbor_hostname
      dnsNames    = [local.harbor_hostname]
      duration    = var.certificate_config.duration
      renewBefore = var.certificate_config.renew_before
    }
  }
}
