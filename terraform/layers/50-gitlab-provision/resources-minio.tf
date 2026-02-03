
resource "kubernetes_namespace" "gitlab" {
  metadata {
    name = "gitlab"
  }
}

# Artifacts
resource "kubernetes_secret" "gitlab_s3_artifacts" {
  metadata {
    name      = "gitlab-s3-artifacts"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    # GitLab Chart Object Storage Connection Format
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = data.vault_generic_secret.s3_artifacts.data["access_key"]
      aws_secret_access_key = data.vault_generic_secret.s3_artifacts.data["secret_key"]
      path_style            = true
    })
  }
}

# LFS
resource "kubernetes_secret" "gitlab_s3_lfs" {
  metadata {
    name      = "gitlab-s3-lfs"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = data.vault_generic_secret.s3_lfs.data["access_key"]
      aws_secret_access_key = data.vault_generic_secret.s3_lfs.data["secret_key"]
      path_style            = true
    })
  }
}

# Uploads
resource "kubernetes_secret" "gitlab_s3_uploads" {
  metadata {
    name      = "gitlab-s3-uploads"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = data.vault_generic_secret.s3_uploads.data["access_key"]
      aws_secret_access_key = data.vault_generic_secret.s3_uploads.data["secret_key"]
      path_style            = true
    })
  }
}

# Packages
resource "kubernetes_secret" "gitlab_s3_packages" {
  metadata {
    name      = "gitlab-s3-packages"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = data.vault_generic_secret.s3_packages.data["access_key"]
      aws_secret_access_key = data.vault_generic_secret.s3_packages.data["secret_key"]
      path_style            = true
    })
  }
}

# Terraform State
resource "kubernetes_secret" "gitlab_s3_terraform_state" {
  metadata {
    name      = "gitlab-s3-terraform-state"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = data.vault_generic_secret.s3_terraform_state.data["access_key"]
      aws_secret_access_key = data.vault_generic_secret.s3_terraform_state.data["secret_key"]
      path_style            = true
    })
  }
}

# Backups
resource "kubernetes_secret" "gitlab_s3_backups" {
  metadata {
    name      = "gitlab-s3-backups"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }

  data = {
    connection = yamlencode({
      provider              = "AWS"
      region                = local.s3_region
      endpoint              = local.s3_endpoint
      aws_access_key_id     = data.vault_generic_secret.s3_backups.data["access_key"]
      aws_secret_access_key = data.vault_generic_secret.s3_backups.data["secret_key"]
      path_style            = true
    })
  }
}
