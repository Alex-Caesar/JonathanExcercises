# ***************************  AKS related resources ************************************

# __________________________  Kubernetes ________________________________________
resource "azurerm_kubernetes_cluster" "ex2_aks" {
  name                = "${var.rg_name}-aks-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  dns_prefix          = var.aks_dns_prefix

  default_node_pool {
    name                        = var.aks_default_np_name
    node_count                  = var.aks_default_np_count
    vm_size                     = var.aks_default_np_size
    temporary_name_for_rotation = "temp-${var.rg_name}-aks-${random_integer.number.result}"
  }

  ingress_application_gateway {
    gateway_name = var.aks_ingress_name
    gateway_id   = azurerm_application_gateway.ex2_app_gw.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# # __________________________  Container Registry ________________________________________
# resource "azurerm_container_registry" "ex2_acr" {
#   name                = "${var.rg_name}-acr-${random_integer.number.result}"
#   resource_group_name = azurerm_resource_group.ex2.name
#   location            = azurerm_resource_group.ex2.location

#   sku                           = "Basic"
#   public_network_access_enabled = false
#   admin_enabled                 = false
# }