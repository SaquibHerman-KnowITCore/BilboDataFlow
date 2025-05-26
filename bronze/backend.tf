resource "azurerm_storage_account" "backend" {
  name                     = "sttb${var.application_name}${var.environment_name}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  is_hns_enabled           = true
  tags = {
    environment = var.environment_name
    project     = var.application_name
    component   = "backend"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name               = "tfstate"
  storage_account_id = azurerm_storage_account.backend.id
  metadata = {
    environment = var.environment_name
    project     = var.application_name
    component   = "tfstate"
  }
  container_access_type = "private"
}
