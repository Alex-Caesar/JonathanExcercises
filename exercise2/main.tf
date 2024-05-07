terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # prevent_deletion_if_contains_resources = true
    }
  }
}

#_________________________________ Base data _____________________________________________________________
data "azurerm_client_config" "current" {}

resource "random_integer" "number" {
  min = 1
  max = 12
}

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.ex2_vnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.ex2_vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.ex2_vnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.ex2_vnet.name}-be_htst"
  listener_name                  = "${azurerm_virtual_network.ex2_vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.ex2_vnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.ex2_vnet.name}-rdrcfg"
  cert_tls_ssl                   = "${var.rg_name}-app-gw-cert"
  vm_nic_ip_name                 = "${var.rg_name}-nic-vm-ip"
  host_name                      = "exercise2.alex.com"
}

#______________________________ Base resources ____________________________________________________________
resource "azurerm_resource_group" "ex2" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_virtual_network" "ex2_vnet" {
  name                = "${var.rg_name}_vnet"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_network_watcher" "ex2_NetworkWatcher" {
  name                = "NetworkWatcher"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
}