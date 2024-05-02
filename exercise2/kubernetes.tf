# ***************************  AKS related resources ************************************



# __________________________  Container Registry __________________________________________
resource "azurerm_container_registry" "ex2_acr" {
  name                = "${var.rg_name}-acr-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku                           = "Basic"
  public_network_access_enabled = false
  admin_enabled                 = false

}