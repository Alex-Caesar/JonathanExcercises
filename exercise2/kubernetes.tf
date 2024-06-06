# ***************************  AKS related resources ************************************

# __________________________  Kubernetes ________________________________________

# Networking
# https://stackoverflow.com/questions/69158600/terraform-how-to-find-azure-kubernetes-aks-vnet-id-for-network-peering
resource "azurerm_virtual_network" "ex2_aks_vnet" {
  name                = "aks-vnet"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
  address_space       = ["10.254.0.0/16"]
}
resource "azurerm_subnet" "ex2_aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_aks_vnet.name
  address_prefixes     = ["10.254.1.0/24"]
}

# Need NSG and rules later

# AKS
resource "azurerm_kubernetes_cluster" "ex2_aks" {
  name                = "${var.rg_name}-aks-${local.number}-${local.string}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  dns_prefix          = var.aks_dns_prefix
  sku_tier            = "Free"

  default_node_pool {
    name           = var.aks_default_np_name
    node_count     = var.aks_default_np_count
    vm_size        = var.aks_default_np_size
    vnet_subnet_id = azurerm_subnet.ex2_aks_subnet.id

    temporary_name_for_rotation = "tempaksnp"
  }

  network_profile {
    network_plugin = "azure"
  }

  node_resource_group = "${azurerm_resource_group.ex2.name}_aks_rg"

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.ex2_app_gw.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  # depends_on = [azurerm_key_vault.ex2_akv, azurerm_key_vault_certificate.ex2_cert_appgw, azurerm_application_gateway.ex2_app_gw]
}
