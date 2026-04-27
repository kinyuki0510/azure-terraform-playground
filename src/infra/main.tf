terraform {
  required_version = "~> 1.14"

  # https://registry.terraform.io/providers/hashicorp/azurerm/latest
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

data "azurerm_client_config" "current" {}

locals {
  sa_suffix = substr(data.azurerm_client_config.current.subscription_id, 0, 8)
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = "${var.location}"
}