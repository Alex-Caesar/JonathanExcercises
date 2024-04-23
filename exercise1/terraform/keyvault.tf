#________________________ AKV associated resources ______________________________________________
resource "azurerm_key_vault" "ex1_akv" {
  name                      = "${var.rg_name}-akv-${random_integer.number.result}"
  resource_group_name       = azurerm_resource_group.ex1.name
  location                  = azurerm_resource_group.ex1.location
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
  enabled_for_deployment    = true
}

# Virtual Machine
resource "azurerm_role_assignment" "vm_role_certs" {
  scope                = azurerm_key_vault.ex1_akv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.ex1_vm_ass_iden.principal_id
}

#  Application Gateway
resource "azurerm_role_assignment" "app_gw_kv_role" {
  scope                = azurerm_key_vault.ex1_akv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_user_assigned_identity.ex1_app_gw_ass_iden.principal_id
}

# Client
resource "azurerm_role_assignment" "client_role_certs" {
  scope                = azurerm_key_vault.ex1_akv.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "client_role_secrets" {
  scope                = azurerm_key_vault.ex1_akv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# _________________________ Secrets and Certs ____________________________________________

resource "azurerm_key_vault_secret" "ex1_akv_db_secret" {
  name         = "${var.rg_name}-db-secret"
  value        = azurerm_mssql_server.ex1_sql_server.administrator_login_password
  key_vault_id = azurerm_key_vault.ex1_akv.id
  # to ensure the connection secret string is created after the value is generated
  depends_on = [azurerm_mssql_database.ex1_sql_db, azurerm_role_assignment.client_role_certs, azurerm_role_assignment.client_role_secrets]
}

resource "azurerm_key_vault_certificate" "ex1_cert_appgw" {
  name         = "${var.rg_name}-cert-appgw"
  key_vault_id = azurerm_key_vault.ex1_akv.id

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