
output "role_id" {
  description = "The RoleID of the Terraform admin AppRole"
  value       = vault_approle_auth_backend_role.terraform_admin.role_id
}

output "approle_path" {
  description = "The path where AppRole auth is enabled"
  value       = vault_auth_backend.approle.path
}

output "role_name" {
  description = "The name of the AppRole"
  value       = vault_approle_auth_backend_role.terraform_admin.role_name
}
