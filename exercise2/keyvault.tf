# ***************************  Keyvault related resources ************************************
resource "azurerm_key_vault" "ex2_akv" {
  name                = "${var.rg_name}-akv-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  # public_network_access_enabled = false
  enable_rbac_authorization = true
  enabled_for_deployment    = true
}

# __________________________  Permissions _______________________________________________

#  Application Gateway
resource "azurerm_role_assignment" "app_gw_kv_role_cert" {
  scope                = azurerm_key_vault.ex2_akv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.ex2_app_gw_ass_iden.principal_id
}

resource "azurerm_role_assignment" "app_gw_kv_role_secret" {
  scope                = azurerm_key_vault.ex2_akv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.ex2_app_gw_ass_iden.principal_id
}

# Client
resource "azurerm_role_assignment" "client_role_certs" {
  scope                = azurerm_key_vault.ex2_akv.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
resource "azurerm_role_assignment" "client_role_secrets" {
  scope                = azurerm_key_vault.ex2_akv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# __________________________  Secrets and Certs _______________________________________________
resource "azurerm_key_vault_secret" "ex2_akv_db_pass" {
  name         = azurerm_postgresql_flexible_server.ex2_psql_serv.administrator_login
  value        = azurerm_postgresql_flexible_server.ex2_psql_serv.administrator_password
  key_vault_id = azurerm_key_vault.ex2_akv.id
  # to ensure the connection secret string is created after the value is generated
  depends_on = [azurerm_postgresql_flexible_server.ex2_psql_serv]
}
resource "azurerm_key_vault_secret" "ex2_gitlab_pass" {
  name         = "gitlab-root"
  value        = var.gitlab_password
  key_vault_id = azurerm_key_vault.ex2_akv.id
}
resource "azurerm_key_vault_certificate" "ex2_cert_appgw" {
  name         = "${var.rg_name}-cert-appgw"
  key_vault_id = azurerm_key_vault.ex2_akv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }
    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 33
      }
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject = "cn=${local.host_name}"
      subject_alternative_names {
        dns_names = ["${local.host_name}"]
      }
      validity_in_months = 3
    }
  }
  depends_on = [azurerm_role_assignment.client_role_certs, azurerm_role_assignment.client_role_secrets]
}