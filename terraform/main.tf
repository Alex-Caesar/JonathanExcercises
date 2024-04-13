terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
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

resource "azurerm_resource_group" "Ex1" {
  name = var.rg-location
  location = var.rg-location
}

resource "azurerm_virtual_network" "Ex1-vnet" {
  name = "Ex1-vnet"
  resource_group_name = azurerm_resource_group.Ex1.name
  location = azurerm_resource_group.Ex1.location
  address_space = [ "10.0.0.0/16" ]
}

