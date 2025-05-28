# Data Lake Storage
resource "azurerm_storage_account" "datalake" {
  name                     = "dl${var.application_name}${var.environment_name}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  is_hns_enabled           = true

  tags = {
    environment = var.environment_name
    project     = var.application_name
    component   = "datalake"
  }
}

resource "azurerm_storage_container" "bronze_datalake" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.datalake.id
  container_access_type = "private"
}

resource "azurerm_storage_data_lake_gen2_path" "winassist_datalake_folder" {
  path               = "winassist"
  filesystem_name    = azurerm_storage_container.bronze_datalake.name
  storage_account_id = azurerm_storage_account.datalake.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "kobra_datalake_folder" {
  path               = "kobra"
  filesystem_name    = azurerm_storage_container.bronze_datalake.name
  storage_account_id = azurerm_storage_account.datalake.id
  resource           = "directory"
}


resource "azurerm_storage_data_lake_gen2_path" "gds_datalake_folder" {
  path               = "gds"
  filesystem_name    = azurerm_storage_container.bronze_datalake.name
  storage_account_id = azurerm_storage_account.datalake.id
  resource           = "directory"
}
