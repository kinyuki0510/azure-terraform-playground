variable "appconfig_name" {
  type        = string
  description = "Name of the bootstrap App Configuration store (e.g. atp-dev-appconfig)"
}

variable "bootstrap_rg" {
  type        = string
  description = "Resource group containing bootstrap resources (Key Vault, App Configuration)"
}

variable "allowed_ips" {
  type        = list(string)
  description = "IP addresses allowed to access Storage and PostgreSQL (e.g. your home IP)"
}

variable "deployer_upn" {
  type        = string
  description = "UPN of the deployer. Used as Entra ID admin for PostgreSQL. Run: az ad signed-in-user show --query userPrincipalName -o tsv"
}
