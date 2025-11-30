
# Bootstrap Root CA
resource "tls_private_key" "vault_ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "vault_ca" {
  private_key_pem = tls_private_key.vault_ca.private_key_pem

  subject {
    common_name  = "on-premise-gitlab-deployment-root-ca-selfsigned"
    organization = "On-Premise GitLab Deployment"
  }

  validity_period_hours = 87600 # 10 Years
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]
}

# On-premise CA Cert for Terraform Provider & Ansible
resource "local_file" "vault_ca" {
  content  = tls_self_signed_cert.vault_ca.cert_pem
  filename = "${path.module}/tls/vault-ca.crt"
}

# Vault Server Certificate for HA Nodes & VIP
resource "tls_private_key" "vault_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "vault_server" {
  private_key_pem = tls_private_key.vault_server.private_key_pem

  subject {
    common_name  = "vault.iac.local"
    organization = "On-Premise GitLab Deployment"
  }

  dns_names = [
    "vault.iac.local",
    "vault",
    "localhost",
    "vault-node-00", "vault-node-01", "vault-node-02"
  ]

  ip_addresses = [
    "127.0.0.1",
    var.vault_compute.ha_config.virtual_ip
  ]
}

resource "tls_locally_signed_cert" "vault_server" {
  cert_request_pem   = tls_cert_request.vault_server.cert_request_pem
  ca_private_key_pem = tls_private_key.vault_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.vault_ca.cert_pem

  validity_period_hours = 8760 # 1 Year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

# Vault Server Cert & Key
resource "local_file" "vault_server_crt" {
  content  = tls_locally_signed_cert.vault_server.cert_pem
  filename = "${path.module}/tls/vault.crt"
}

resource "local_file" "vault_server_key" {
  content         = tls_private_key.vault_server.private_key_pem
  filename        = "${path.module}/tls/vault.key"
  file_permission = "0600"
}
