resource "azurerm_storage_account" "app" {
  name                     = "${replace(var.prefix, "-", "")}app${local.sa_suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  # false にするとTerraformプロバイダーがqueue propertiesをキー認証で読もうとして失敗する既知バグのため true
  shared_access_key_enabled       = true
  default_to_oauth_authentication = true
  public_network_access_enabled   = true

  network_rules {
    default_action = "Deny"
    ip_rules       = var.allowed_ips
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "original" {
  name               = "original"
  storage_account_id = azurerm_storage_account.app.id
}

resource "azurerm_storage_container" "temporary" {
  name               = "temporary"
  storage_account_id = azurerm_storage_account.app.id
}

resource "azurerm_storage_container" "processed" {
  name               = "processed"
  storage_account_id = azurerm_storage_account.app.id
}

resource "azurerm_storage_account" "asset" {
  name                     = "${replace(var.prefix, "-", "")}asset${local.sa_suffix}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  # Functionsランタイムがアクセスキーを使用するため有効のまま
  shared_access_key_enabled       = true
  public_network_access_enabled   = true

  network_rules {
    default_action = "Deny"
    ip_rules       = var.allowed_ips
    bypass         = ["AzureServices"]
  }
}

# Function App ZIP置き場。ZIP名でFunction App単位を区別する
resource "azurerm_storage_container" "function" {
  name               = "function"
  storage_account_id = azurerm_storage_account.asset.id
}