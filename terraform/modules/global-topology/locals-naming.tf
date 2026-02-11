
################################################################
#### DO NOT CHANGE BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ####
#### THIS IS THE SINGLE SOURCE OF TRUTH ACROSS ALL SERVICES ####
################################################################

locals {
  network_baseline = var.network_baseline
  service_catalog  = var.service_catalog
}

/**
 * 1. Role Name (Identity) - Define "What it is"
 *      Format: iac-vault-core-role
 * 2. DNS Name (Context) - Define "Where it is"
 *      Format: core.vault.production.iac.local
 * 3. Certificate OU (Context) - Define "Status and Ownership"
 *      Format: ["Env=production", "Runtime=baremetal", "Tag=critical"]
 */

locals {
  # 1. Dependency Roles (e.g., gitlab-postgres-role)
  #    Logic: Parent Service Name + Dependency Component Name
  dependency_roles = flatten([
    for s in var.service_catalog : [
      for d_key, d_data in s.dependencies : {
        key = "${s.name}-${d_key}"

        # Format: ${ProjectCode}-${Service}-${Component}
        #    e.g. core-gitlab-postgres
        role_name = "${s.project_code}-${s.name}-${d_data.component}"

        # Format: {component}.{service}.{stage}.iac.local
        #    e.g. postgres.gitlab.production.iac.local
        dns_san = [
          "${d_data.component}.${s.name}.${s.stage}.${var.domain_suffix}"
        ]

        # Inject Context
        ou = [
          "Provider=${d_data.provider}", # e.g., Provider=aws
          "Env=${s.stage}",
          "Owner=${s.owner}",
          "Project=${s.project_code}",
          "Runtime=${d_data.runtime}"
        ]

        ttl_stage = s.stage
      }
    ]
  ])

  # 2. Component Roles (e.g., gitlab-frontend-role)
  #    Logic: Parent Service Name + Component Name
  component_roles = flatten([
    for s in var.service_catalog : [
      for c_key, c_data in s.components : {
        key = "${s.name}-${c_key}"

        # Format: ${ProjectCode}-${Service}-${Component}
        #    e.g. core-gitlab-frontend
        role_name = "${s.project_code}-${s.name}-${c_key}"

        # Format: {subdomain}.{service}.{stage}.iac.local
        #    e.g. kas.gitlab.production.iac.local
        dns_san = [
          for sub in c_data.subdomains :
          "${sub}.${s.name}.${s.stage}.${var.domain_suffix}"
        ]

        ou = [
          "Provider=${s.provider}", # e.g., Provider=aws
          "Env=${s.stage}",
          "Owner=${s.owner}",
          "Project=${s.project_code}",
          "Runtime=${s.runtime}"
        ]

        ttl_stage = s.stage
      }
    ]
  ])

  naming_map = merge(
    { for item in local.dependency_roles : item.key => item },
    { for item in local.component_roles : item.key => item }
  )
}
