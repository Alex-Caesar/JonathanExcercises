# ***************************  AKS related resources ************************************

# __________________________  Kubernetes ________________________________________

resource "azurerm_kubernetes_cluster" "ex2_aks" {
  name                = "${var.rg_name}-aks-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  dns_prefix          = "ex2aks"

  default_node_pool {
    name                        = "default"
    node_count                  = 1
    vm_size                     = "Standard_D2_V2"
    temporary_name_for_rotation = "temp-${var.rg_name}-aks-${random_integer.number.result}"
  }

  identity {
    type = "SystemAssigned"
  }

}

# __________________________  Container Registry ________________________________________
resource "azurerm_container_registry" "ex2_acr" {
  name                = "${var.rg_name}-acr-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku                           = "Basic"
  public_network_access_enabled = false
  admin_enabled                 = false

}