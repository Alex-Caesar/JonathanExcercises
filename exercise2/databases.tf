
resource "azurerm_postgresql_server" "ex2_psql_serv" {
  name                = "${var.rg_name}-psql-server-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku_name   = "B_Gen4_1"
  version    = "11"
  storage_mb = "5120"
  #   backup_retention_days = 7 # off for sake of testing

  ssl_enforcement_enabled       = false
  public_network_access_enabled = false

  administrator_login          = var.db_admin
  administrator_login_password = var.db_password
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