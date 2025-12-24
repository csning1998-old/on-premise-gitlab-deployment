
variable "harbor_hostname" {
  description = "The FQDN for Harbor access"
  type        = string
  default     = "harbor.iac.local" # mod in tfvars in future.
}

variable "k8s_physical_ip" {
  description = "MicroK8s Node Physical IP (Bypass MetalLB VIP)"
  type        = string
  default     = "172.16.135.200" # Microk8s Node Physical IP
}

variable "k8s_api_port" {
  description = "MicroK8s API Port"
  type        = string
  default     = "16443"
}
