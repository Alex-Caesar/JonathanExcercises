# # ***************************  AKS related resources ************************************

# __________________________  Kubernetes ________________________________________
resource "azurerm_kubernetes_cluster" "ex2_aks" {
  name                = "${var.rg_name}-aks-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  dns_prefix          = var.aks_dns_prefix
  sku_tier            = "Standard"

  default_node_pool {
    name                        = var.aks_default_np_name
    node_count                  = var.aks_default_np_count
    vm_size                     = var.aks_default_np_size
    temporary_name_for_rotation = "tempaksnp"
  }

  network_profile {
    network_plugin = "azure"
  }

  node_resource_group = "${azurerm_resource_group.ex2.name}_rg"

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.ex2_app_gw.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# __________________________  Container Registry ________________________________________
resource "azurerm_container_registry" "ex2_acr" {
  name                = "${var.rg_name}acr${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku = "Basic"
  # public_network_access_enabled = false
  admin_enabled = false
}
resource "azurerm_role_assignment" "ex2_acr_role" {
  principal_id                     = azurerm_kubernetes_cluster.ex2_aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.ex2_acr.id
  skip_service_principal_aad_check = true
}
# tf https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_task
# need cache rule https://learn.microsoft.com/en-us/azure/container-registry/tutorial-artifact-cache
