resource "random_password" "pg_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                  = "${var.prefix}-pg"
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  version               = "16"
  sku_name              = "B_Standard_B1ms"
  storage_mb            = 32768
  backup_retention_days = 7

  administrator_login    = "pgadmin"
  administrator_password = random_password.pg_admin.result

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
  }
}

# デプロイ実行者をEntra ID管理者に設定（開発者がazure CLIトークンでpsql接続できる）
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "deployer" {
  server_name         = azurerm_postgresql_flexible_server.main.name
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_client_config.current.object_id
  principal_name      = var.deployer_upn
  principal_type      = "User"
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# 0.0.0.0 → 0.0.0.0 はAzureサービス（Container Apps等）からのアクセスを許可するAzure固有の記法
# https://learn.microsoft.com/azure/postgresql/network/how-to-networking-servers-deployed-public-access-add-firewall-rules
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "dev_ips" {
  for_each = toset(var.allowed_ips)

  name             = "allow-dev-${replace(each.value, ".", "-")}"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = each.value
  end_ip_address   = each.value
}
