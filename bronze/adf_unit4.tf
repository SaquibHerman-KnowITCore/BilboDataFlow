resource "azurerm_data_factory_linked_custom_service" "ls_rest_unit4" {
  name            = "ls_rest_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id
  type            = "RestService"
  description     = "REST linked service for Unit4 API"

  type_properties_json = jsonencode({
    url                               = "https://integrationerpexternal-api-v2-prod.azurewebsites.net/"
    authenticationType                = "Anonymous"
    enableServerCertificateValidation = true
    additionalHeaders = {
      "X-API-Key" = "@Microsoft.KeyVault(SecretName=unit4-api-key;LinkedServiceName=ls-kv-${var.application_name}-${var.environment_name})"
    }
  })
}

resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "ls_datalake_unit4" {
  name                = "ls_datalake_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id     = azurerm_data_factory.main.id
  description         = "Linked service to ADLS Gen2 using account key"
  url                 = "https://dlbilbodataflow${var.environment_name}.dfs.core.windows.net"
  storage_account_key = azurerm_storage_account.datalake.primary_access_key
}

resource "azurerm_data_factory_custom_dataset" "ds_rest_json_unit4" {
  name            = "ds_rest_json_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id
  type            = "RestResource"
  description     = "REST dataset for Unit4 accounts endpoint"

  linked_service {
    name = azurerm_data_factory_linked_custom_service.ls_rest_unit4.name
  }

  parameters = {
    companyCode = "string"
  }

  type_properties_json = jsonencode({
    relativeUrl = "accounts?companyCode=@{dataset().companyCode}"
  })
}

resource "azurerm_data_factory_dataset_delimited_text" "ds_datalake_csv_unit4" {
  name                = "ds_datalake_csv_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id     = azurerm_data_factory.main.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.ls_datalake_unit4.name

  parameters = {
    folderPath = "string"
    fileName   = "string"
  }

  azure_blob_fs_location {
    file_system = "bronze"
    path        = "@{dataset().folderPath}/@{dataset().fileName}"
  }

  column_delimiter    = ";"
  row_delimiter       = "\n"
  first_row_as_header = true
  encoding            = "UTF-8"
  escape_character    = "\\"
  quote_character     = "\""
}

resource "azurerm_data_factory_pipeline" "pl_unit4" {
  name            = "pl_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id

  parameters = {
    companyCodeList = jsonencode([
      "BSFS"
      /*, "BSAB", "BSFG", "BSFK", "BSMO", "BSGR", "BSLV",
      "BSFL", "BSGA", "BSHA", "BSNO", "BSSU", "BSKU"*/
    ])
  }

  activities_json = jsonencode([
    {
      name           = "ForEachCompany"
      type           = "ForEach"
      dependsOn      = []
      userProperties = []
      typeProperties = {
        isSequential = true
        items = {
          value = "@pipeline().parameters.companyCodeList"
          type  = "Expression"
        }
        activities = [
          {
            name = "Copy_Unit4_JSON_To_CSV"
            type = "Copy"
            typeProperties = {
              source = {
                type               = "RestSource"
                httpRequestTimeout = "00:01:40"
                requestMethod      = "GET"
              },
              sink = {
                type              = "DelimitedTextSink"
                writeBatchSize    = 0
                writeBatchTimeout = "00:00:00"
              },
              enableStaging = false
            },
            inputs = [
              {
                referenceName = azurerm_data_factory_custom_dataset.ds_rest_json_unit4.name
                type          = "DatasetReference"
                parameters = {
                  companyCode = "@item()"
                }
              }
            ],
            outputs = [
              {
                referenceName = azurerm_data_factory_dataset_delimited_text.ds_datalake_csv_unit4.name
                type          = "DatasetReference"
                parameters = {
                  folderPath = "@concat('unit4/', formatDateTime(utcNow(),'yyyy/MM/dd'))",
                  fileName   = "@concat(item(), '.csv')"
                }
              }
            ]
          }
        ]
      }
    }
  ])
}
