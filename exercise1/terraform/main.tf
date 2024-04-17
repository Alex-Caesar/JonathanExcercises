terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0"
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

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.ex1_vnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.ex1_vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.ex1_vnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.ex1_vnet.name}-be_htst"
  listener_name                  = "${azurerm_virtual_network.ex1_vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.ex1_vnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.ex1_vnet.name}-rdrcfg"
  cert_tls_ssl                   = "${var.rg_name}_app_gw_cert"
}

#______________________________ Base resources ________________________________________________________
resource "azurerm_resource_group" "ex1" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_virtual_network" "ex1_vnet" {
  name                = "${var.rg_name}_vnet"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  address_space       = ["10.0.0.0/16"]
}

#_______________________ private endpoint network resources _______________________________________________
resource "azurerm_subnet" "ex1_subnet_pe" {
  name                 = "${var.rg_name}_subnet_pe"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "ex1_sql_netsecg" {
  name                = "${var.rg_name}_pe_netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_subnet_network_security_group_association" "ex1_secg_asso_pe" {
  subnet_id                 = azurerm_subnet.ex1_subnet_pe.id
  network_security_group_id = azurerm_network_security_group.ex1_sql_netsecg.id
}

resource "azurerm_private_dns_zone" "ex1_priv_dns_zone" {
  name                = "${var.rg_name}.privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1_priv_dns_z_net_link" {
  name                  = "${var.rg_name}_priv_dns_z_net_link"
  resource_group_name   = azurerm_resource_group.ex1.name
  registration_enabled  = true
  private_dns_zone_name = azurerm_private_dns_zone.ex1_priv_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.ex1_vnet.id
}

# resource "azurerm_private_endpoint" "ex1_redis_private_end" {
#   name                = "${var.rg_name}_redis_private_end"
#   resource_group_name = azurerm_resource_group.ex1.name
#   location            = azurerm_resource_group.ex1.location

#   subnet_id = azurerm_subnet.ex1_subnet_pe.id

#   private_service_connection {
#     name                           = "${var.rg_name}_redis_private_serv_conn"
#     private_connection_resource_id = azurerm_redis_cache.ex1_vm_redis.id
#     subresource_names              = ["redisCache"]
#     is_manual_connection           = false
#   }

#   private_dns_zone_group {
#     name                 = "${var.rg_name}_private_dns_zg_redis"
#     private_dns_zone_ids = [azurerm_private_dns_zone.ex1_priv_dns_zone.id]
#   }
# }

resource "azurerm_private_endpoint" "ex1_sqldb_private_end" {
  name                = "${var.rg_name}_sql_private_end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1_subnet_pe.id

  private_service_connection {
    name                           = "${var.rg_name}_sql_private_serv_conn"
    private_connection_resource_id = azurerm_mssql_server.ex1_sql_server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_sql"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1_priv_dns_zone.id]
  }
}

# ********************** Database associated resources **************************************************

#_______________________ SQL Database resources _______________________________________________
resource "azurerm_storage_account" "ex1_store_acc" {
  name                     = "${var.rg_name}store9acc"
  resource_group_name      = azurerm_resource_group.ex1.name
  location                 = azurerm_resource_group.ex1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_server" "ex1_sql_server" {
  name                = "${var.rg_name}sqlserver"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  version             = "12.0"

  administrator_login          = var.db_admin
  administrator_login_password = var.db_password
}

resource "azurerm_mssql_database" "ex1_sql_db" {
  name      = "${var.rg_name}_sql_db"
  server_id = azurerm_mssql_server.ex1_sql_server.id

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = false # for the sake of testing
  }
}

#_______________________ Redis Database resources _______________________________________________
# resource "azurerm_redis_cache" "ex1_vm_redis" {
#   name                          = "${var.rg_name}_redis"
#   resource_group_name           = azurerm_resource_group.ex1.name
#   location                      = azurerm_resource_group.ex1.location
#   capacity                      = 1
#   family                        = "C"
#   sku_name                      = "Basic"
#   public_network_access_enabled = false
# }

# ************************** VM associated resources *******************************************

#___________________________ VM network resources ______________________________
resource "azurerm_subnet" "ex1_subnet_vm" {
  name                 = "${var.rg_name}_subnet_vm"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "ex1_vm_netsecg" {
  name                = "${var.rg_name}_vm_netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_subnet_network_security_group_association" "ex1_secg_asso_vm" {
  subnet_id                 = azurerm_subnet.ex1_subnet_vm.id
  network_security_group_id = azurerm_network_security_group.ex1_vm_netsecg.id
}

resource "azurerm_network_security_rule" "ex1_netsec_r_vm_443" {
  name                        = "${var.rg_name}_netsec_r_443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "443"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_vm_netsecg.name
}

resource "azurerm_network_interface" "ex1_nic_vm" {
  name                = "${var.rg_name}_nic_vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  ip_configuration {
    name                          = "${var.rg_name}_nic_vm_ip"
    subnet_id                     = azurerm_subnet.ex1_subnet_vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "ex1_vm_netsecg_nic_asso" {
  network_interface_id      = azurerm_network_interface.ex1_nic_vm.id
  network_security_group_id = azurerm_network_security_group.ex1_vm_netsecg.id
}

#___________________________ VM associated resources ______________________________

resource "azurerm_virtual_machine" "ex1_vm" {
  name                = "${var.rg_name}_vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  network_interface_ids = [azurerm_network_interface.ex1_nic_vm.id]

  vm_size = "Standard_B1s"

  storage_os_disk {
    name          = "${var.rg_name}_vm_os_disk"
    caching       = "ReadWrite"
    create_option = "fromImage"
    os_type       = "Linux"
  }

  os_profile {
    admin_username = var.vm_admin
    admin_password = var.vm_password
    computer_name  = var.vm_name
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

}

# # Custom Script Extension to install NGINX and configure it
# resource "azurerm_virtual_machine_extension" "ex1_vm_extension" {
#   name                       = "nginx_setup"
#   virtual_machine_id         = azurerm_virtual_machine.ex1_vm.id
#   publisher                  = "Microsoft.Azure.Extensions"
#   type                       = "CustomScript"
#   type_handler_version       = "2.0"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
#     {
#         "commandToExecute": " apt-get update &&  apt-get install nginx -y &&  sed -i 's/# listen 443 ssl/listen 443 ssl/g' /etc/nginx/sites-available/default &&  systemctl restart nginx"
#     }
# SETTINGS

#   depends_on = [azurerm_virtual_machine.ex1_vm]
# }

#___________________________ App Gateway network resources ______________________________
resource "azurerm_subnet" "ex1_subnet_app_gw" {
  name                 = "${var.rg_name}_subnet_app_gw"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "ex1_app_gw_netsecg" {
  name                = "${var.rg_name}_app_gw"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_subnet_network_security_group_association" "ex1_secg_asso_app_gw" {
  subnet_id                 = azurerm_subnet.ex1_subnet_app_gw.id
  network_security_group_id = azurerm_network_security_group.ex1_app_gw_netsecg.id
}

resource "azurerm_network_security_rule" "https_rule_app_gw" {
  name                        = "AllowHTTPS"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_app_gw_netsecg.name
}

# Allow inbound traffic on port 65503-65534 for Application Gateway health probes
resource "azurerm_network_security_rule" "health_probe_inbound" {
  name                        = "AllowHealthProbe"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_app_gw_netsecg.name
}

# Deny all inbound traffic not explicitly allowed
resource "azurerm_network_security_rule" "deny_all_inbound" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_app_gw_netsecg.name
}

resource "azurerm_public_ip" "ex1_app_gw_pub_ip" {
  name                = "${var.rg_name}_app_gw_pub_ip"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_user_assigned_identity" "ex1_app_gw_ass_iden" {
  name                = "${var.rg_name}_app_gw_ass_iden"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_application_gateway" "ex1_app_gw" {
  name                = "${var.rg_name}_app_gw"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.rg_name}_app_gw_ip_config"
    subnet_id = azurerm_subnet.ex1_subnet_app_gw.id
  }
  # # Bonus attempt
  # waf_configuration {
  #   enabled          = true
  #   firewall_mode    = "Detection"
  #   rule_set_version = 3.2
  # }
  ssl_certificate {
    name                = local.cert_tls_ssl
    key_vault_secret_id = azurerm_key_vault_certificate.ex1_cert_appgw.secret_id
  }
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.ex1_app_gw_pub_ip.id
  }
  frontend_port {
    name = local.frontend_port_name
    port = 443
  }
  backend_address_pool {
    name = local.backend_address_pool_name
  }
  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
  }
  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Https"
    ssl_certificate_name           = local.cert_tls_ssl
  }
  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 10
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

  # need a redirect for port 80 or non TSL/SSL traffic ?

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ex1_app_gw_ass_iden.id]
  }

  #ensuring the cert is ready to be utilized
  depends_on = [azurerm_key_vault.ex1_akv, azurerm_user_assigned_identity.ex1_app_gw_ass_iden, azurerm_key_vault_certificate.ex1_cert_appgw]
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "ex1_app_gw_nic_asso" {
  network_interface_id    = azurerm_network_interface.ex1_nic_vm.id
  ip_configuration_name   = "${var.rg_name}_vm_nic_app_gw_asso_config"
  backend_address_pool_id = tolist(azurerm_application_gateway.ex1_app_gw.backend_address_pool).0.id
}


#________________________ AKV associated resources ______________________________________________
resource "azurerm_key_vault" "ex1_akv" {
  name                      = "${var.rg_name}-akv-876987"
  resource_group_name       = azurerm_resource_group.ex1.name
  location                  = azurerm_resource_group.ex1.location
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

data "azurerm_role_definition" "keyvault_cert_user" {
  name = "Key Vault Certificate User"
}

resource "azurerm_role_assignment" "app_gw_kv_role" {
  scope                = azurerm_key_vault.ex1_akv.id
  role_definition_name = data.azurerm_role_definition.keyvault_cert_user.name
  principal_id         = azurerm_user_assigned_identity.ex1_app_gw_ass_iden.principal_id
}

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
        days_before_expiry = 30
      }
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "cn=${var.rg_name}-cert-appgw"
      validity_in_months = 12
    }
  }
  depends_on = [azurerm_role_assignment.client_role_certs, azurerm_role_assignment.client_role_secrets]
}