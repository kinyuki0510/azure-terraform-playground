resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "app_blob" {
  name                       = "${var.prefix}-app-blob-diag"
  target_resource_id         = "${azurerm_storage_account.app.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "asset_blob" {
  name                       = "${var.prefix}-asset-blob-diag"
  target_resource_id         = "${azurerm_storage_account.asset.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
  }
}
