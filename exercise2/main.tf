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
      prevent_deletion_if_contains_resources = true
    }
  }
}

#_________________________________ Base data _____________________________________________________________
data "azurerm_client_config" "current" {}

resource "random_integer" "number" {
  min = 1
  max = 500
}

#______________________________ Base resources ________________________________________________________
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