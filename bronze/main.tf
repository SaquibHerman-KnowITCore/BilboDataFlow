resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}-${var.environment_name}"
  location = var.primary_location
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {

  name                      = "kv-${var.application_name}-${var.environment_name}"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  enable_rbac_authorization = true

}

resource "azurerm_data_factory" "main" {
  name                = "adf-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment_name
    application = var.application_name
    component   = "data_factory"
  }
}

resource "azurerm_data_factory_linked_service_key_vault" "main" {
  name            = "ls-kv-${var.application_name}-${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id
  key_vault_id    = azurerm_key_vault.main.id
  description     = "Key Vault linked service for Biibolaget Data Platform"
}
