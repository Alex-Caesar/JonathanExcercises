#________________________ AKV associated resources ______________________________________________
resource "azurerm_key_vault" "ex2_akv" {
  name                          = "${var.rg_name}-akv-${random_integer.number.result}"
  resource_group_name           = azurerm_resource_group.ex2.name
  location                      = azurerm_resource_group.ex2.location
  sku_name                      = "standard"
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_network_access_enabled = false
  enable_rbac_authorization     = true
  enabled_for_deployment        = true
}