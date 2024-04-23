terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.99.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
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
  cert_tls_ssl                   = "${var.rg_name}-app-gw-cert"
  vm_nic_ip_name                 = "${var.rg_name}-nic-vm-ip"
}

resource "random_integer" "number" {
  min = 1
  max = 501
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

resource "azurerm_subnet_network_security_group_association" "ex1_secg_asso_pe" {
  subnet_id                 = azurerm_subnet.ex1_subnet_pe.id
  network_security_group_id = azurerm_network_security_group.ex1_sql_netsecg.id
}

# ********************** Database associated resources **************************************************

# _______________________ SQL network resources _______________________________________________
resource "azurerm_network_security_group" "ex1_sql_netsecg" {
  name                = "${var.rg_name}_pe_netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

# the Following two rules are ref from https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/connectivity-architecture-overview?view=azuresql&tabs=current#:~:text=You%20can%20use%20a%20network%20security%20group%20to%20control%20access%20to%20the%20SQL%20Managed%20Instance%20data%20endpoint%20by%20filtering%20traffic%20on%20port%201433%20and%20ports%2011000%2D11999%20when%20SQL%20Managed%20Instance%20is%20configured%20for%20redirect%20connections.
resource "azurerm_network_security_rule" "filter1433" {
  name                        = "filter1433"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "1433"
  destination_port_range      = "1433"
  source_address_prefix       = azurerm_subnet.ex1_subnet_vm.address_prefixes.0
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_sql_netsecg.name
}

resource "azurerm_network_security_rule" "filterRedirect" {
  name                        = "filterRedirect"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "11000-11999"
  destination_port_range      = "11000-11999"
  source_address_prefix       = azurerm_subnet.ex1_subnet_pe.address_prefixes.0
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_sql_netsecg.name
}

#_______________________ SQL Database resources _______________________________________________
resource "azurerm_private_dns_zone" "ex1_priv_dns_zone_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1_priv_dns_z_net_link_sql" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_sql"
  resource_group_name   = azurerm_resource_group.ex1.name
  private_dns_zone_name = azurerm_private_dns_zone.ex1_priv_dns_zone_sql.name
  virtual_network_id    = azurerm_virtual_network.ex1_vnet.id
}

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
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1_priv_dns_zone_sql.id]
  }
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

resource "azurerm_private_dns_zone" "ex1_priv_dns_zone_redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1_priv_dns_z_net_link_redis" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_redis"
  resource_group_name   = azurerm_resource_group.ex1.name
  private_dns_zone_name = azurerm_private_dns_zone.ex1_priv_dns_zone_redis.name
  virtual_network_id    = azurerm_virtual_network.ex1_vnet.id
}

resource "azurerm_private_endpoint" "ex1_redis_private_end" {
  name                = "${var.rg_name}_redis_private_end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1_subnet_pe.id

  private_service_connection {
    name                           = "${var.rg_name}_redis_private_serv_conn"
    private_connection_resource_id = azurerm_redis_cache.ex1_redis.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1_priv_dns_zone_redis.id]
  }
}

resource "azurerm_redis_cache" "ex1_redis" {
  name                          = "${var.rg_name}-redis"
  resource_group_name           = azurerm_resource_group.ex1.name
  location                      = azurerm_resource_group.ex1.location
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Basic"
  public_network_access_enabled = false
}

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

resource "azurerm_network_security_rule" "https_rule_vm_gw" {
  name                        = "AllowHTTPSGW"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_vm_netsecg.name
}

resource "azurerm_network_security_rule" "https_rule_vm_lb" {
  name                        = "AllowHTTPSLB"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_vm_netsecg.name
}

# _________________________ SSH capability ____________________________________________________
# resource "azurerm_network_security_rule" "https_rule_vm_ssh" {
#   name                         = "AllowSsh"
#   priority                     = 300
#   direction                    = "Inbound"
#   access                       = "Allow"
#   protocol                     = "Tcp"
#   source_port_range            = "*"
#   destination_port_range       = "22"
#   source_address_prefix        = "108.203.115.95/32"
#   destination_address_prefixes = azurerm_subnet.ex1_subnet_vm.address_prefixes
#   resource_group_name          = azurerm_resource_group.ex1.name
#   network_security_group_name  = azurerm_network_security_group.ex1_vm_netsecg.name
# }

# resource "azurerm_public_ip" "ex1_vm_pub_ip" {
#   name                = "${var.rg_name}_vm_pub_ip"
#   location            = azurerm_resource_group.ex1.location
#   resource_group_name = azurerm_resource_group.ex1.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# resource "azurerm_subnet_network_security_group_association" "ex1_secg_asso_vm" {
#   subnet_id                 = azurerm_subnet.ex1_subnet_vm.id
#   network_security_group_id = azurerm_network_security_group.ex1_vm_netsecg.id
# }

# resource "azurerm_network_interface" "ex1_nic_vm" {
#   name                = "${var.rg_name}_nic_vm"
#   resource_group_name = azurerm_resource_group.ex1.name
#   location            = azurerm_resource_group.ex1.location

#   ip_configuration {
#     name                          = local.vm_nic_ip_name
#     subnet_id                     = azurerm_subnet.ex1_subnet_vm.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.ex1_vm_pub_ip.id
#   }
# }

#___________________________ VM associated resources ______________________________

resource "azurerm_linux_virtual_machine" "ex1_vm" {
  name                = "${var.rg_name}_vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  network_interface_ids = [azurerm_network_interface.ex1_nic_vm.id]
  size                  = var.vm_size

  os_disk {
    name                 = "${var.rg_name}_vm_os_disk"
    caching              = var.vm_caching
    storage_account_type = var.vm_storage_account_type
  }

  computer_name = var.vm_name

  admin_username = var.vm_admin
  admin_password = var.vm_password

  # admin_ssh_key {
  #   username   = var.vm_admin
  #   public_key = file("./vm.pub")
  # }

  source_image_reference {
    publisher = var.vm_publisher
    offer     = var.vm_offer
    sku       = var.vm_sku
    version   = var.vm_version
  }

  secret {
    certificate {
      url = azurerm_key_vault_certificate.ex1_cert_appgw.secret_id
    }
    key_vault_id = azurerm_key_vault.ex1_akv.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ex1_vm_ass_iden.id]
  }

  disable_password_authentication = false

  depends_on = [azurerm_key_vault.ex1_akv]
}

# resource "azurerm_virtual_machine_extension" "ex1_vm_extension_akv_grab" {
#   name                       = "akv_grab"
#   virtual_machine_id         = azurerm_linux_virtual_machine.ex1_vm.id
#   publisher                  = "Microsoft.Azure.KeyVault"
#   type                       = "KeyVaultForLinux"
#   type_handler_version       = "2.0"
#   automatic_upgrade_enabled  = true
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
#     {
#       "secretsManagementSettings": {
#           "pollingIntervalInS": "10",
#           "requireInitialSync": true,
#           "certificateStoreLocation": "/etc/nginx/ssl",
#           "observedCertificates": [ "${azurerm_key_vault_certificate.ex1_cert_appgw.secret_id}" ]
#         },
#         "authenticationSettings": {
#           "msiEndpoint":  "http://169.254.169.254/metadata/identity",
#           "msiClientId":  "${azurerm_user_assigned_identity.ex1_vm_ass_iden.client_id}"
#         }
#     }
# SETTINGS

#   depends_on = [azurerm_linux_virtual_machine.ex1_vm]
# }

# Custom Script Extension to install NGINX and configure it
# resource "azurerm_virtual_machine_extension" "ex1_vm_extension_nginx_setup" {
#   name                       = "nginx_setup"
#   virtual_machine_id         = azurerm_linux_virtual_machine.ex1_vm.id
#   publisher                  = "Microsoft.Azure.Extensions"
#   type                       = "CustomScript"
#   type_handler_version       = "2.0"
#   automatic_upgrade_enabled  = false
#   auto_upgrade_minor_version = false

#   settings = <<SETTINGS
#     {
#         "script": "${base64encode(file(var.nginxConfig))}"
#     }
# SETTINGS

#   depends_on = [azurerm_linux_virtual_machine.ex1_vm]
# }

#___________________________ App Gateway Related resources ______________________________
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

# NSG Rules required ports by application gateway please see https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#:~:text=V2%3A%20Ports%2065200%2D65535

# Inbound Client traffic
resource "azurerm_network_security_rule" "https_rule_app_gw" {
  name                        = "AllowHTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = [azurerm_subnet.ex1_subnet_app_gw.address_prefixes.0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_app_gw_netsecg.name
}

# Inbound Infrastructure Ports
resource "azurerm_network_security_rule" "lb_inbound" {
  name                        = "AllowLb"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_app_gw_netsecg.name
}

resource "azurerm_network_security_rule" "health_probe_inbound" {
  name                        = "AllowHealthProbe"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "*" #Terraform specific constraint requires internet traffic
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_app_gw_netsecg.name
}

# Outbound rule
resource "azurerm_network_security_rule" "outbound_internet" {
  name                        = "outboundInternet"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
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
  sku                 = "Standard"
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
  ssl_certificate {
    name                = local.cert_tls_ssl
    key_vault_secret_id = azurerm_key_vault_certificate.ex1_cert_appgw.secret_id
  }
  trusted_root_certificate {
    name = local.cert_tls_ssl
    key_vault_secret_id = azurerm_key_vault_certificate.ex1_cert_appgw.secret_id
  }
  gateway_ip_configuration {
    name      = "${var.rg_name}_app_gw_ip_config"
    subnet_id = azurerm_subnet.ex1_subnet_app_gw.id
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
    host_name             = "exercise1.alex.com"
    trusted_root_certificate_names = [local.cert_tls_ssl]
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
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }


  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ex1_app_gw_ass_iden.id]
  }

  #ensuring the cert is ready to be utilized
  depends_on = [azurerm_key_vault.ex1_akv, azurerm_user_assigned_identity.ex1_app_gw_ass_iden, azurerm_key_vault_certificate.ex1_cert_appgw]
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "ex1_app_gw_nic_asso" {
  network_interface_id    = azurerm_network_interface.ex1_nic_vm.id
  ip_configuration_name   = local.vm_nic_ip_name
  backend_address_pool_id = one(azurerm_application_gateway.ex1_app_gw.backend_address_pool).id
}


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

# VM
resource "azurerm_user_assigned_identity" "ex1_vm_ass_iden" {
  name                = "${var.rg_name}_vm_ass_iden"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_role_assignment" "vm_role_certs" {
  scope                = azurerm_key_vault.ex1_akv.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = azurerm_user_assigned_identity.ex1_vm_ass_iden.principal_id
}

# Secrets and Certs

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

      subject = "cn=exercise1.alex.com"
      subject_alternative_names {
        dns_names = ["exercise1.alex.com"]
      }
      validity_in_months = 3
    }
  }
  depends_on = [azurerm_role_assignment.client_role_certs, azurerm_role_assignment.client_role_secrets]
}