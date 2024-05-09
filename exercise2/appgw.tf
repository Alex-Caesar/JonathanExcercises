#___________________________ App Gateway Related resources ______________________________
resource "azurerm_subnet" "ex2_subnet_app_gw" {
  name                 = "${var.rg_name}_subnet_app_gw"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_user_assigned_identity" "ex2_app_gw_ass_iden" {
  name                = "${var.rg_name}_app_gw_ass_iden"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
}

resource "azurerm_network_security_group" "ex2_app_gw_netsecg" {
  name                = "${var.rg_name}_app_gw"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
}

resource "azurerm_subnet_network_security_group_association" "ex2_secg_asso_app_gw" {
  subnet_id                 = azurerm_subnet.ex2_subnet_app_gw.id
  network_security_group_id = azurerm_network_security_group.ex2_app_gw_netsecg.id
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
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_subnet.ex2_subnet_app_gw.address_prefixes.0
  resource_group_name         = azurerm_resource_group.ex2.name
  network_security_group_name = azurerm_network_security_group.ex2_app_gw_netsecg.name
}

# Inbound Infrastructure Ports
resource "azurerm_network_security_rule" "lb_hp_inbound" {
  name                        = "AllowLbHealthProbe"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex2.name
  network_security_group_name = azurerm_network_security_group.ex2_app_gw_netsecg.name
}

resource "azurerm_network_security_rule" "gw_hp_inbound" {
  name                        = "AllowGwHealthProbe"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex2.name
  network_security_group_name = azurerm_network_security_group.ex2_app_gw_netsecg.name
}

# Outbound rule
resource "azurerm_network_security_rule" "outbound_internet" {
  name                        = "outboundInternet"
  priority                    = 300
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex2.name
  network_security_group_name = azurerm_network_security_group.ex2_app_gw_netsecg.name
}

resource "azurerm_public_ip" "ex2_app_gw_pub_ip" {
  name                = "${var.rg_name}_app_gw_pub_ip"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "ex2_app_gw" {
  name                = "${var.rg_name}_app_gw"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }
  ssl_certificate {
    name                = local.cert_tls_ssl
    key_vault_secret_id = azurerm_key_vault_certificate.ex2_cert_appgw.secret_id
  }
  trusted_root_certificate {
    name                = local.cert_tls_ssl
    key_vault_secret_id = azurerm_key_vault_certificate.ex2_cert_appgw.secret_id
  }
  gateway_ip_configuration {
    name      = "${var.rg_name}_app_gw_ip_config"
    subnet_id = azurerm_subnet.ex2_subnet_app_gw.id
  }
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.ex2_app_gw_pub_ip.id
  }
  frontend_port {
    name = local.frontend_port_name
    port = 443
  }
  backend_address_pool {
    name = local.backend_address_pool_name
  }
  backend_http_settings {
    name                           = local.http_setting_name
    cookie_based_affinity          = "Disabled"
    port                           = 443
    protocol                       = "Https"
    request_timeout                = 60
    host_name                      = local.host_name
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
    priority                   = 10
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ex2_app_gw_ass_iden.id]
  }
  #ensuring the cert is ready to be utilized
  depends_on = [azurerm_key_vault.ex2_akv, azurerm_user_assigned_identity.ex2_app_gw_ass_iden, azurerm_key_vault_certificate.ex2_cert_appgw]
}

# tf https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering
# need to do vnet peering https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering