
variable "vault_addr" {
  description = "The address of the Vault server"
  type        = string
}

variable "root_domain" {
  description = "The root domain of the organization"
  type        = string
}

variable "root_ca_common_name" {
  description = "The common name of the root CA"
  type        = string
}

variable "ingress_roles" {
  description = "Map of Ingress PKI Roles configuration"
  type = map(object({
    name            = string
    allowed_domains = list(string)
    max_ttl         = number
    ttl             = number
  }))
}

variable "database_roles" {
  description = "Map of Database PKI Roles configuration"
  type = map(object({
    name            = string
    allowed_domains = list(string)
    max_ttl         = number
    ttl             = number
  }))
}

variable "auth_backends" {
  description = "Map of Auth Backends to enable"
  type = map(object({
    type = string
    path = string
  }))
  default = {}
}

variable "pki_engine_config" {
  description = "Configuration for the PKI Secrets Engine"
  type = object({
    path                      = string
    default_lease_ttl_seconds = number
    max_lease_ttl_seconds     = number
  })
}
