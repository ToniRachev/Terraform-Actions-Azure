terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.37.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_service_plan" "taskboard_plan" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_mssql_server" "sqlserver" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "taskboard_db" {
  name                 = var.sql_database_name
  server_id            = azurerm_mssql_server.sqlserver.id
  license_type         = "LicenseIncluded"
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  sku_name             = "S0"
  max_size_gb          = 2
  storage_account_type = "Local"
}

resource "azurerm_mssql_firewall_rule" "firewall_rule" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_linux_web_app" "taskboard_app" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.taskboard_plan.id
  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.taskboard_db.name};User ID=${azurerm_mssql_server.sqlserver.administrator_login};Password=${azurerm_mssql_server.sqlserver.administrator_login_password};Trusted_Connection=False;MultipleActiveResultSets=True;"
  }
}

resource "azurerm_app_service_source_control" "taskboard_source_control" {
  app_id                 = azurerm_linux_web_app.taskboard_app.id
  repo_url               = var.repo_url
  branch                 = "main"
  use_manual_integration = true
}
