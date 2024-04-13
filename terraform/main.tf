terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

#--------------------------------- Base data -------------------------------------------------------------
data "azurerm_client_config" "current" {}

#------------------------------ Base resources --------------------------------------------------------
resource "azurerm_resource_group" "ex1" {
  name     = var.rg-location
  location = var.rg-location
}

resource "azurerm_virtual_network" "ex1-vnet" {
  name                = "${var.rg-name}-vnet"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  address_space       = ["10.0.0.0/16"]
}

#----------------------- SQL associated resources -----------------------------------------------
resource "azurerm_subnet" "ex1-subnet-sql" {
  name                 = "${var.rg-name}-subnet-sql"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1-vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_network_security_group" "ex1-sql-netsecg" {
  name                = "${var.rg-name}-sql-netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_subnet_network_security_group_association" "ex1-secg-asso" {
  subnet_id = azurerm_subnet.ex1-subnet-sql.id
  network_security_group_id = azurerm_network_security_group.ex1-sql-netsecg.id
}

# resource "azurerm_private_endpoint" "ex1-cosmosdb-sqldb-private-end" {
#   name = "${var.rg-name}-cosmosdb-private-end"
#   resource_group_name = azurerm_resource_group.ex1.name
#   location            = azurerm_resource_group.ex1.location
# subnet_id = azurerm_subnet.ex1-subnet-sql.id
#  private_service_connection {
#    # todo
#  }
# }

resource "azurerm_cosmosdb_account" "ex1-cosmosdb-ac" {
  name                = "${var.rg-name}-cosmos-account"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  offer_type          = "Standard"
  free_tier_enabled   = true
  consistency_policy {
    consistency_level = "BoundedStaleness"
  }
  geo_location {
    location          = azurerm_resource_group.ex1.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "ex1-cosmosdb-sqldb" {
  name                = "${var.rg-name}-cosmosdb-sqldb"
  resource_group_name = azurerm_resource_group.ex1.name
  account_name        = azurerm_cosmosdb_account.ex1-cosmosdb-ac.name
}

resource "azurerm_cosmosdb_sql_container" "ex1-cosmosdb-sqlcontainer" {
  name                  = "${var.rg-name}-cosmosdb-sqlcontainer"
  resource_group_name   = azurerm_resource_group.ex1.name
  account_name          = azurerm_cosmosdb_account.ex1-cosmosdb-ac.name
  database_name         = azurerm_cosmosdb_sql_database.ex1-cosmosdb-sqldb.account_name
  partition_key_path    = "/definition/id" # todo
  partition_key_version = 1
  # todo
}

#--------------------------- VM associated resources ------------------------------
resource "azurerm_subnet" "ex1-subnet-vm" {
  name                 = "${var.rg-name}-subnet-vm"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1-vnet.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_network_security_group" "ex1-vm-netsecg" {
  name                = "${var.rg-name}-vm-netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

#  VM HERE

resource "azurerm_redis_cache" "ex1-vm-redis" {
  name                = "${var.rg-name}-redis"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  capacity            = 1
  family              = C
  sku_name            = "Basic"
  # todo
}

#------------------------ AKV associated resources ----------------------------------------------
resource "azurerm_key_vault" "ex1-akv" {
  name                = "${var.rg-name}-akv"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current
}


resource "azurerm_key_vault_access_policy" "ex1-akv-acc-pol-vm" {
  key_vault_id = azurerm_key_vault.ex1-akv.id
  tenant_id    = data.azurerm_client_config.current.id
  object_id    = data.azurerm_client_config.current.object_id # todo: needs to be the security group of the vm

  key_permissions = ["Get", "List"]
}

# this is specifically for when creating the sql db that it then puts the connection key into the AKV
resource "azurerm_key_vault_access_policy" "ex1-akv-acc-pol-tf" {
  key_vault_id = azurerm_key_vault.ex1-akv.id
  tenant_id    = data.azurerm_client_config.current.id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = ["Create", "Update"]
}

resource "azurerm_key_vault_secret" "ex1-akv-db-secret" {
  name         = "${var.rg-name}-db-secret"
  value        = azurerm_cosmosdb_account.ex1-cosmosdb-ac.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.ex1-akv.id
  # to ensure the connection secret string is created after the value is generated
  depends_on = [azurerm_cosmosdb_account.ex1-cosmosdb-ac]
}