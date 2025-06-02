# Linked Service to connect ADF with Unit4 REST API
resource "azurerm_data_factory_linked_custom_service" "ls_rest_unit4" {
  name            = "ls_rest_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id
  type            = "RestService"
  description     = "REST linked service for Unit4 API"

  /*
   * The API key (X-API-Key) should be retrieved securely from Azure Key Vault.
   * Currently, this needs to be configured manually in the Azure Portal.
   * The section below shows how to automate it (when supported) via `authHeaders`.
   */
  type_properties_json = <<JSON
{
  "url": "https://integrationerpexternal-api-v2-prod.azurewebsites.net/",
  "authenticationType": "Anonymous",
  "enableServerCertificateValidation": true
  /*
  "authHeaders" = "{
    "X-API-Key" = {
      type       = "AzureKeyVaultSecret",
      secretName = "unit4-api-key",
      secretVersion = "latest",
      store = {
        referenceName = azurerm_data_factory_linked_service_key_vault.main.name,
        type          = "LinkedServiceReference"
      }
    }
  }"
  */
}
JSON
}

# Linked Service to connect ADF with ADLS Gen2 using storage account key
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "ls_datalake_unit4" {
  name                = "ls_datalake_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id     = azurerm_data_factory.main.id
  description         = "Linked service to ADLS Gen2 using account key"
  url                 = "https://dlbilbodataflow${var.environment_name}.dfs.core.windows.net"
  storage_account_key = azurerm_storage_account.datalake.primary_access_key
}

# Dataset representing the REST API endpoint with company code as parameter
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

# Dataset representing the destination CSV file in Data Lake
resource "azurerm_data_factory_dataset_delimited_text" "ds_datalake_csv_unit4" {
  name                = "ds_datalake_csv_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id     = azurerm_data_factory.main.id
  linked_service_name = azurerm_data_factory_linked_service_data_lake_storage_gen2.ls_datalake_unit4.name

  parameters = {
    folderPath = "string"
    fileName   = "string"
  }

  azure_blob_fs_location {
    file_system = "bronze" # Bronze layer for raw data
    path        = "@{dataset().folderPath}"
    filename    = "@{dataset().fileName}"
  }

  column_delimiter    = ";"  # Fields are separated by semicolon
  row_delimiter       = "\n" # Each record is on a new line
  first_row_as_header = true # First row contains column headers
  encoding            = "UTF-8"
  escape_character    = "\\"
  quote_character     = "\""
}

# Pipeline to extract data from Unit4 API and write to CSV in Data Lake
resource "azurerm_data_factory_pipeline" "pl_unit4" {
  name            = "pl_unit4_${var.application_name}_${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id

  parameters = {
    # List of company codes to iterate over in pipeline
    companyCodeList = jsonencode([
      "BSFB", "GSDE", "BSGB", "BSFR", "BSUM", "BSUP", "BSAB",
      "BSFG", "BSFS", "BSFK", "BSMO", "BSGR", "BSLV", "BSFL",
      "BSGÄ", "BSHÄ", "BSNO", "BSSU", "BSKU"
    ])
  }

  activities_json = jsonencode([
    {
      name = "ForEachCompany", # Loop activity to run for each company
      type = "ForEach",
      typeProperties = {
        isSequential = true, # Run in sequence
        items = {
          value = "@pipeline().parameters.companyCodeList",
          type  = "Expression"
        },
        activities = [
          {
            name = "Copy_Unit4_JSON_To_CSV", # Copy activity per company code
            type = "Copy",
            typeProperties = {
              source = {
                type               = "RestSource",
                httpRequestTimeout = "00:01:40",
                requestMethod      = "GET"
              },
              sink = {
                type              = "DelimitedTextSink",
                writeBatchSize    = 0,
                writeBatchTimeout = "00:00:00"
              },
              enableStaging = false
            },
            inputs = [
              {
                referenceName = azurerm_data_factory_custom_dataset.ds_rest_json_unit4.name,
                type          = "DatasetReference",
                parameters = {
                  companyCode = "@item()" # Inject current item into dataset
                }
              }
            ],
            outputs = [
              {
                referenceName = azurerm_data_factory_dataset_delimited_text.ds_datalake_csv_unit4.name,
                type          = "DatasetReference",
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

# Nightly trigger to schedule the pipeline every day at 20:00 UTC
resource "azurerm_data_factory_trigger_schedule" "tr_unit4_nightly" {
  name            = "tr_unit4_nightly_${var.application_name}_${var.environment_name}"
  data_factory_id = azurerm_data_factory.main.id
  description     = "Nightly trigger for Unit4 pipeline at 20:00 UTC"
  activated       = true

  frequency = "Day"
  interval  = 1
  time_zone = "UTC"
  schedule {
    hours   = [20] # 8 PM UTC
    minutes = [0]
  }

  pipeline_name = azurerm_data_factory_pipeline.pl_unit4.name

  pipeline_parameters = {
    # Pass company code list to pipeline on trigger
    companyCodeList = jsonencode([
      "BSFB", "GSDE", "BSGB", "BSFR", "BSUM", "BSUP", "BSAB",
      "BSFG", "BSFS", "BSFK", "BSMO", "BSGR", "BSLV", "BSFL",
      "BSGÄ", "BSHÄ", "BSNO", "BSSU", "BSKU"
    ])
  }

  depends_on = [
    azurerm_data_factory_pipeline.pl_unit4
  ]
}
