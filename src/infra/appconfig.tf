data "azurerm_app_configuration" "bootstrap" {
  name                = var.appconfig_name
  resource_group_name = var.bootstrap_rg
}

data "azurerm_app_configuration_key" "prefix" {
  configuration_store_id = data.azurerm_app_configuration.bootstrap.id
  key                    = "/resource/prefix"
}

data "azurerm_app_configuration_key" "location" {
  configuration_store_id = data.azurerm_app_configuration.bootstrap.id
  key                    = "/resource/location"
}

data "azurerm_app_configuration_key" "ghcr_image" {
  configuration_store_id = data.azurerm_app_configuration.bootstrap.id
  key                    = "/resource/ghcr-image"
}

locals {
  prefix     = data.azurerm_app_configuration_key.prefix.value
  location   = data.azurerm_app_configuration_key.location.value
  ghcr_image = data.azurerm_app_configuration_key.ghcr_image.value
}
