#_______________________ private endpoint network resources _______________________________________________
resource "azurerm_subnet" "ex1_subnet_pe" {
  name                 = "${var.rg_name}_subnet_pe"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "ex1_secg_asso_pe" {
  subnet_id                 = azurerm_subnet.ex1_subnet_pe.id
  network_security_group_id = azurerm_network_security_group.ex1_sql_netsecg.id
}

# ********************** Database associated resources **************************************************

# _______________________ SQL network resources _______________________________________________
resource "azurerm_network_security_group" "ex1_sql_netsecg" {
  name                = "${var.rg_name}_pe_netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

# the Following two rules are ref from https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/connectivity-architecture-overview?view=azuresql&tabs=current#:~:text=You%20can%20use%20a%20network%20security%20group%20to%20control%20access%20to%20the%20SQL%20Managed%20Instance%20data%20endpoint%20by%20filtering%20traffic%20on%20port%201433%20and%20ports%2011000%2D11999%20when%20SQL%20Managed%20Instance%20is%20configured%20for%20redirect%20connections.
resource "azurerm_network_security_rule" "filter1433" {
  name                        = "filter1433"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "1433"
  destination_port_range      = "1433"
  source_address_prefix       = azurerm_subnet.ex1_subnet_vm.address_prefixes.0
  destination_address_prefix  = azurerm_subnet.ex1_subnet_pe.address_prefixes.0
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_sql_netsecg.name
}

resource "azurerm_network_security_rule" "filterRedirect" {
  name                        = "filterRedirect"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "11000-11999"
  destination_port_range      = "11000-11999"
  source_address_prefix       = azurerm_subnet.ex1_subnet_pe.address_prefixes.0
  destination_address_prefix  = azurerm_subnet.ex1_subnet_vm.address_prefixes.0
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_sql_netsecg.name
}

#_______________________ SQL Database resources _______________________________________________
resource "azurerm_private_dns_zone" "ex1_priv_dns_zone_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1_priv_dns_z_net_link_sql" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_sql"
  resource_group_name   = azurerm_resource_group.ex1.name
  private_dns_zone_name = azurerm_private_dns_zone.ex1_priv_dns_zone_sql.name
  virtual_network_id    = azurerm_virtual_network.ex1_vnet.id
}

resource "azurerm_private_endpoint" "ex1_sqldb_private_end" {
  name                = "${var.rg_name}_sql_private_end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1_subnet_pe.id

  private_service_connection {
    name                           = "${var.rg_name}_sql_private_serv_conn"
    private_connection_resource_id = azurerm_mssql_server.ex1_sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_sql"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1_priv_dns_zone_sql.id]
  }
}

resource "azurerm_mssql_server" "ex1_sql_server" {
  name                = "${var.rg_name}sqlserver"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  version             = "12.0"

  administrator_login          = var.db_admin
  administrator_login_password = var.db_password
}

resource "azurerm_mssql_database" "ex1_sql_db" {
  name      = "${var.rg_name}_sql_db"
  server_id = azurerm_mssql_server.ex1_sql_server.id

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false # false for the sake of testing
  }
}

#_______________________ Redis Database resources _______________________________________________

resource "azurerm_private_dns_zone" "ex1_priv_dns_zone_redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1_priv_dns_z_net_link_redis" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_redis"
  resource_group_name   = azurerm_resource_group.ex1.name
  private_dns_zone_name = azurerm_private_dns_zone.ex1_priv_dns_zone_redis.name
  virtual_network_id    = azurerm_virtual_network.ex1_vnet.id
}

resource "azurerm_private_endpoint" "ex1_redis_private_end" {
  name                = "${var.rg_name}_redis_private_end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1_subnet_pe.id

  private_service_connection {
    name                           = "${var.rg_name}_redis_private_serv_conn"
    private_connection_resource_id = azurerm_redis_cache.ex1_redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1_priv_dns_zone_redis.id]
  }
}

resource "azurerm_redis_cache" "ex1_redis" {
  name                          = "${var.rg_name}-redis"
  resource_group_name           = azurerm_resource_group.ex1.name
  location                      = azurerm_resource_group.ex1.location
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Basic"
  public_network_access_enabled = false
}