output "container_app_fqdn" {
  value = azurerm_container_app.api.latest_revision_fqdn
}

