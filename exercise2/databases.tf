# ***************************  Database related resources ************************************

# __________________________  Private Endpoint  ______________________________________________
resource "azurerm_subnet" "ex2_db_pe" {
  name                 = "${var.rg_name}-psql-server-${random_integer.number.result}"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}


# __________________________  Postgres  ______________________________________________________
resource "azurerm_postgresql_server" "ex2_psql_serv" {
  name                = "${var.rg_name}-psql-server-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku_name              = var.psql_sku
  version               = var.psql_ver
  storage_mb            = var.psql_store_mb
  backup_retention_days = var.psql_backup_ret

  ssl_enforcement_enabled       = false
  public_network_access_enabled = false

  administrator_login          = var.psql_admin
  administrator_login_password = var.psql_password
}
resource "azurerm_postgresql_database" "ex2_psql-db" {
  name                = "${var.rg_name}-psql-db-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  server_name         = azurerm_postgresql_server.ex2_psql_serv.name

  charset   = "UTF8"
  collation = "English_United States.1252"

  lifecycle {
    prevent_destroy = false #false for sake of testing
  }
}