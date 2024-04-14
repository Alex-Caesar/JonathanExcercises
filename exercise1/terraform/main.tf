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

# ********************** Database associated resources **************************************************

#----------------------- Database network resources -----------------------------------------------
resource "azurerm_subnet" "ex1-subnet-pe" {
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
  subnet_id                 = azurerm_subnet.ex1-subnet-pe.id
  network_security_group_id = azurerm_network_security_group.ex1-sql-netsecg.id
}

resource "azurerm_private_dns_zone" "ex1-priv-dns-zone" {
  name                = "${var.rg-name}.privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1-priv-dns-z-net-link" {
  name                = "${var.rg-name}-priv-dns-z-net-link"
  resource_group_name = azurerm_resource_group.ex1.name

  private_dns_zone_name = azurerm_private_dns_zone.ex1-priv-dns-zone.name
  virtual_network_id    = azurerm_virtual_network.ex1-vnet.id
}

resource "azurerm_private_endpoint" "ex1-redis-private-end" {
  name                = "${var.rg-name}-redis-private-end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1-subnet-pe.id

  private_service_connection {
    name                           = "${var.rg-name}-redis-private-serv-conn"
    private_connection_resource_id = azurerm_redis_cache.ex1-vm-redis.id
    subresource_names              = ["file", "blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg-name}-private-dns-zg"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1-priv-dns-zone.id]
  }
}

resource "azurerm_private_endpoint" "ex1-sqldb-private-end" {
  name                = "${var.rg-name}-sql-private-end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1-subnet-pe.id

  private_service_connection {
    name                           = "${var.rg-name}-sql-private-serv-conn"
    private_connection_resource_id = azurerm_mssql_database.ex1-sql-db.id
    subresource_names              = ["file", "blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg-name}-private-dns-zg"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1-priv-dns-zone.id]
  }
}

#----------------------- SQL Database resources -----------------------------------------------
resource "azurerm_storage_account" "ex1-store-acc" {
  name                     = "${var.rg-name}-store-acc"
  resource_group_name      = azurerm_resource_group.ex1.name
  location                 = azurerm_resource_group.ex1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_server" "ex1-sql-server" {
  name                = "${var.rg-name}-sql-server"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  version             = "12.0"

  administrator_login          = var.db-admin
  administrator_login_password = var.db-password
}

resource "azurerm_mssql_database" "ex1-sql-db" {
  name      = "${var.rg-name}-sql-db"
  server_id = azurerm_mssql_server.ex1-sql-server.id

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

#----------------------- Redis Database resources -----------------------------------------------
resource "azurerm_redis_cache" "ex1-vm-redis" {
  name                = "${var.rg-name}-redis"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  capacity            = 1
  family              = "C"
  sku_name            = "Basic"
  public_network_access_enabled = false
}

# ************************** VM associated resources *******************************************

#--------------------------- VM network resources ------------------------------
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

  # did not add rule for 443 traffic yet cause no public ip so unreachable ?
}

resource "azurerm_network_interface" "ex1-nic-vm" {
  name                = "${var.rg-name}-nic-vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  ip_configuration {
    name                          = "${var.rg-name}-nic-vm-ip"
    subnet_id                     = azurerm_network_security_group.ex1-vm-netsecg.id
    private_ip_address_allocation = "static"
  }
}

#--------------------------- VM associated resources ------------------------------

resource "azurerm_virtual_machine" "ex1-vm" {
  name                = "${var.rg-name}-vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  network_interface_ids = [azurerm_network_interface.ex1-nic-vm]

  vm_size = "A1_2"

  storage_os_disk {
    name          = "${var.rg-name}-vm-os-disk"
    caching       = "ReadWrite"
    create_option = "fromImage"
    disk_size_gb  = 4
    os_type       = "Linux"
  }

  os_profile {
    admin_username = var.vm-admin
    admin_password = var.vm-password
    computer_name  = var.vm_name
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

# todo need an extention to do the startup

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
  value        = azurerm_mssql_server.ex1-sql-server.administrator_login_password
  key_vault_id = azurerm_key_vault.ex1-akv.id
  # to ensure the connection secret string is created after the value is generated
  depends_on = [azurerm_storage_account.ex1-store-acc]
}