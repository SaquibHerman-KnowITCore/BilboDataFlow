resource "azurerm_storage_account" "storage" {
  name                     = "st${var.application_name}${var.environment_name}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  is_hns_enabled           = true
  tags = {
    environment = var.environment_name
    project     = var.application_name
    component   = "storage"
  }
}

resource "azurerm_storage_container" "bronze_ingestion" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_storage_data_lake_gen2_path" "kobra_ingestion_folder" {
  path               = "kobra"
  filesystem_name    = azurerm_storage_container.bronze_ingestion.name
  storage_account_id = azurerm_storage_account.storage.id
  resource           = "directory"
}
