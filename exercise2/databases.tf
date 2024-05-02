# ***************************  Database related resources ************************************

# __________________________  Private Endpoint  ______________________________________________

# General Networking
resource "azurerm_subnet" "ex2_subnet_pe" {
  name                 = "${var.rg_name}-subnet-pe"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}
resource "azurerm_subnet_network_security_group_association" "ex2_secg_asso_pe" {
  subnet_id                 = azurerm_subnet.ex2_subnet_pe.id
  network_security_group_id = azurerm_network_security_group.ex2_sql_netsecg.id
}
resource "azurerm_network_security_group" "ex2_sql_netsecg" {
  name                = "${var.rg_name}_pe_netsecg"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
}

# NSG Rules

# TODO

# Postgres
resource "azurerm_private_dns_zone" "ex2_priv_dns_zone_psql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.ex2.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex2_priv_dns_z_net_link_psql" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_psql"
  resource_group_name   = azurerm_resource_group.ex2.name
  private_dns_zone_name = azurerm_private_dns_zone.ex2_priv_dns_zone_psql.name
  virtual_network_id    = azurerm_virtual_network.ex2_vnet.id
}

resource "azurerm_private_endpoint" "ex2_psql_private_end" {
  name                = "${var.rg_name}_psql_private_end"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  subnet_id = azurerm_subnet.ex2_subnet_pe.id

  private_service_connection {
    name                           = "${var.rg_name}_sql_private_serv_conn"
    private_connection_resource_id = azurerm_postgresql_flexible_server.ex2_psql_serv.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_psql"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex2_priv_dns_zone_psql.id]
  }
}


# __________________________  Postgres  ______________________________________________________
resource "azurerm_postgresql_flexible_server" "ex2_psql_serv" {
  name                = "${var.rg_name}-psql-server-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  version             = var.psql_ver
  delegated_subnet_id = azurerm_subnet.example.id
  private_dns_zone_id = azurerm_private_dns_zone.example.id

  administrator_login    = var.psql_admin
  administrator_password = var.psql_password
  zone                   = "1"

  storage_mb   = var.psql_store_mb
  storage_tier = var.psql_store_tier

  sku_name   = var.psql_sku
  depends_on = [azurerm_private_dns_zone_virtual_network_link.example]
}
resource "azurerm_postgresql_flexible_server_database" "ex2_psql_db" {
  name      = "${var.rg_name}-psql-db-${random_integer.number.result}"
  server_id = azurerm_postgresql_flexible_server.ex2_psql_serv.id
  collation = "en_US.utf8"
  charset   = "utf8"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false #false for sake of testing
  }
}