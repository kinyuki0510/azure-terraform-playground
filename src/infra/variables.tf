variable "prefix" {
  type        = string
  description = "resource name prefix (e.g. atp-dev)"
}

variable "allowed_ips" {
  type        = list(string)
  description = "IP addresses allowed to access Storage and PostgreSQL (e.g. your home IP)"
}

variable "location" {
  type        = string
  description = "Azure region (e.g. japaneast)"
  default     = "japaneast"
}

variable "deployer_upn" {
  type        = string
  description = "UPN of the deployer. Used as Entra ID admin for PostgreSQL. Run: az ad signed-in-user show --query userPrincipalName -o tsv"
}
