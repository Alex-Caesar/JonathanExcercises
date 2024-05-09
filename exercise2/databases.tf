# ***************************  Database related resources ************************************

# _____________________________  Redis  ______________________________________________________
resource "azurerm_subnet" "ex2_subnet_pe" {
  name                 = "${var.rg_name}_subnet_pe"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_vnet.name
  address_prefixes     = ["10.0.20.0/24"]
}

resource "azurerm_private_dns_zone" "ex2_priv_dns_zone_redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.ex2.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex2_priv_dns_z_net_link_redis" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_redis"
  resource_group_name   = azurerm_resource_group.ex2.name
  private_dns_zone_name = azurerm_private_dns_zone.ex2_priv_dns_zone_redis.name
  virtual_network_id    = azurerm_virtual_network.ex2_vnet.id
}

resource "azurerm_private_endpoint" "ex2_redis_private_end" {
  name                = "${var.rg_name}_redis_private_end"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  subnet_id = azurerm_subnet.ex2_subnet_pe.id

  private_service_connection {
    name                           = "${var.rg_name}_redis_private_serv_conn"
    private_connection_resource_id = azurerm_redis_cache.ex2_redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex2_priv_dns_zone_redis.id]
  }
}

resource "azurerm_redis_cache" "ex2_redis" {
  name                          = "${var.rg_name}-redis"
  resource_group_name           = azurerm_resource_group.ex2.name
  location                      = azurerm_resource_group.ex2.location
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Basic"
  public_network_access_enabled = false
}

# __________________________  Postgres  ______________________________________________________

# General Networking
resource "azurerm_subnet" "ex2_subnet_psql" {
  name                 = "${var.rg_name}-subnet-psql"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
resource "azurerm_network_security_group" "ex2_nsg_psql" {
  name                = "ex2_nsg_psql"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.ex2_subnet_psql.id
  network_security_group_id = azurerm_network_security_group.ex2_nsg_psql.id
}

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

  subnet_id = azurerm_subnet.ex2_subnet_psql.id

  private_service_connection {
    name                           = "${var.rg_name}_psql_private_serv_conn"
    private_connection_resource_id = azurerm_postgresql_flexible_server.ex2_psql_serv.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_psql"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex2_priv_dns_zone_psql.id]
  }
}

#  https://docs.gitlab.com/charts/advanced/external-db/index.html
resource "azurerm_postgresql_flexible_server" "ex2_psql_serv" {
  name                = "${var.rg_name}-psql-server-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  version             = var.psql_ver
  delegated_subnet_id = azurerm_subnet.ex2_subnet_psql.id
  private_dns_zone_id = azurerm_private_dns_zone.ex2_priv_dns_zone_psql.id

  administrator_login    = var.psql_admin
  administrator_password = var.psql_password

  storage_mb   = var.psql_store_mb
  storage_tier = var.psql_store_tier

  sku_name = var.psql_sku

}
resource "azurerm_postgresql_flexible_server_database" "ex2_psql_db" {
  name      = "gitlabhq_production"
  server_id = azurerm_postgresql_flexible_server.ex2_psql_serv.id
  collation = "en_US.utf8"
  charset   = "utf8"

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false #false for sake of testing
  }
}