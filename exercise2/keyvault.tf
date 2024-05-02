# ***************************  Keyvault related resources ************************************
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

# __________________________  Secrets and Certs __________________________________________
resource "azurerm_key_vault_secret" "ex2_akv_db_pass" {
  name         = var.psql_admin
  value        = azurerm_postgresql_server.ex2_psql_serv.administrator_login_password
  key_vault_id = azurerm_key_vault.ex2_akv.id
  # to ensure the connection secret string is created after the value is generated
  depends_on = [azurerm_postgresql_server.ex2_psql_serv]
}