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

#--------------------------------- Base data -------------------------------------------------------------
data "azurerm_client_config" "current" {}

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.ex1-vnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.ex1-vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.ex1-vnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.ex1-vnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.ex1-vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.ex1-vnet.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.ex1-vnet.name}-rdrcfg"
  cert_tls_ssl                   = "${var.rg-name}-app-gw-cert"
}

#------------------------------ Base resources --------------------------------------------------------
resource "azurerm_resource_group" "ex1" {
  name     = var.rg-location
  location = var.rg-location
}

resource "azurerm_virtual_network" "ex1-vnet" {
  name                = "${var.rg-name}-vnet"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  address_space       = ["10.0.0.0/16"]
}

#----------------------- private endpoint network resources -----------------------------------------------
resource "azurerm_subnet" "ex1-subnet-pe" {
  name                 = "${var.rg-name}-subnet-pe"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1-vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_network_security_group" "ex1-sql-netsecg" {
  name                = "${var.rg-name}-pe-netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_subnet_network_security_group_association" "ex1-secg-asso" {
  subnet_id                 = azurerm_subnet.ex1-subnet-pe.id
  network_security_group_id = azurerm_network_security_group.ex1-sql-netsecg.id
}

resource "azurerm_private_dns_zone" "ex1-priv-dns-zone" {
  name                = "${var.rg-name}.privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "ex1-priv-dns-z-net-link" {
  name                = "${var.rg-name}-priv-dns-z-net-link"
  resource_group_name = azurerm_resource_group.ex1.name

  private_dns_zone_name = azurerm_private_dns_zone.ex1-priv-dns-zone.name
  virtual_network_id    = azurerm_virtual_network.ex1-vnet.id
}

resource "azurerm_private_endpoint" "ex1-redis-private-end" {
  name                = "${var.rg-name}-redis-private-end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1-subnet-pe.id

  private_service_connection {
    name                           = "${var.rg-name}-redis-private-serv-conn"
    private_connection_resource_id = azurerm_redis_cache.ex1-vm-redis.id
    # subresource_names = [  ] # not sure
    is_manual_connection = false
  }

  private_dns_zone_group {
    name                 = "${var.rg-name}-private-dns-zg-redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1-priv-dns-zone.id]
  }
}

resource "azurerm_private_endpoint" "ex1-sqldb-private-end" {
  name                = "${var.rg-name}-sql-private-end"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  subnet_id = azurerm_subnet.ex1-subnet-pe.id

  private_service_connection {
    name                           = "${var.rg-name}-sql-private-serv-conn"
    private_connection_resource_id = azurerm_mssql_server.ex1-sql-server.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg-name}-private-dns-zg-sql"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex1-priv-dns-zone.id]
  }
}

# ********************** Database associated resources **************************************************

#----------------------- SQL Database resources -----------------------------------------------
resource "azurerm_storage_account" "ex1-store-acc" {
  name                     = "${var.rg-name}0store0acc"
  resource_group_name      = azurerm_resource_group.ex1.name
  location                 = azurerm_resource_group.ex1.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_mssql_server" "ex1-sql-server" {
  name                = "${var.rg-name}-sql-server"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location
  version             = "12.0"

  administrator_login          = var.db-admin
  administrator_login_password = var.db-password
}

resource "azurerm_mssql_database" "ex1-sql-db" {
  name      = "${var.rg-name}-sql-db"
  server_id = azurerm_mssql_server.ex1-sql-server.id

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

#----------------------- Redis Database resources -----------------------------------------------
resource "azurerm_redis_cache" "ex1-vm-redis" {
  name                          = "${var.rg-name}-redis"
  resource_group_name           = azurerm_resource_group.ex1.name
  location                      = azurerm_resource_group.ex1.location
  capacity                      = 1
  family                        = "C"
  sku_name                      = "Basic"
  public_network_access_enabled = false
}

# ************************** VM associated resources *******************************************

#--------------------------- VM network resources ------------------------------
resource "azurerm_subnet" "ex1-subnet-vm" {
  name                 = "${var.rg-name}-subnet-vm"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1-vnet.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_network_security_group" "ex1-vm-netsecg" {
  name                = "${var.rg-name}-vm-netsecg"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_network_security_rule" "ex1-netsec-r-vm-443" {
  name                        = "${var.rg-name}-netsec-r-443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "443"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1-vm-netsecg.name
}

resource "azurerm_network_interface" "ex1-nic-vm" {
  name                = "${var.rg-name}-nic-vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  ip_configuration {
    name                          = "${var.rg-name}-nic-vm-ip"
    subnet_id                     = azurerm_subnet.ex1-subnet-vm.id
    private_ip_address_allocation = "Dynamic"
  }
}

#--------------------------- VM associated resources ------------------------------

resource "azurerm_virtual_machine" "ex1-vm" {
  name                = "${var.rg-name}-vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  network_interface_ids = [azurerm_network_interface.ex1-nic-vm.id]

  vm_size = "A1_2"

  storage_os_disk {
    name          = "${var.rg-name}-vm-os-disk"
    caching       = "ReadWrite"
    create_option = "fromImage"
    disk_size_gb  = 4
    os_type       = "Linux"
  }

  os_profile {
    admin_username = var.vm-admin
    admin_password = var.vm-password
    computer_name  = var.vm_name
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

}

# Custom Script Extension to install NGINX and configure it
resource "azurerm_virtual_machine_extension" "example" {
  name                 = "nginx-setup"
  virtual_machine_id   = azurerm_virtual_machine.ex1-vm.id   
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
        "script": "https://raw.githubusercontent.com/Alex-Caesar/JonathanExercises/exercise1/exercise1/nginxSetup.bash",
        "commandToExecute": "bash installNginx.sh"
    }
SETTINGS
}

# # Provisioner to configure NGINX to listen on port 443
# resource "null_resource" "nginx_configuration" {
#   provisioner "remote-exec" {
#     inline = [
#       "sudo sed -i 's/listen 80;/listen 443 ssl;/g' /etc/nginx/sites-available/default",
#       "sudo systemctl restart nginx"
#     ]

#     connection {
#       type        = "ssh"
#       host        = azurerm_public_ip.example.ip_address
#       user        = "adminuser"
#       password    = "Password1234!" # Replace with your password or use SSH key
#     }
#   }

#   depends_on = [azurerm_virtual_machine_extension.example]
# }

#--------------------------- App Gateway network resources ------------------------------
resource "azurerm_subnet" "ex1-subnet-app-gw" {
  name                 = "${var.rg-name}-subnet-app-gw"
  resource_group_name  = azurerm_resource_group.ex1.name
  virtual_network_name = azurerm_virtual_network.ex1-vnet.name
  address_prefixes     = ["10.3.0.0/24"]
}

resource "azurerm_network_security_group" "ex1-app-gw" {
  name                = "${var.rg-name}-app-gw"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name

  # todo allow 80 and 443 for incoming traffic?
}

resource "azurerm_user_assigned_identity" "ex1-app-gw-ass-iden" {
  name                = "${var.rg-name}-app-gw-ass-iden"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
}

resource "azurerm_application_gateway" "ex1-app-gw" {
  name                = "${var.rg-name}-app-gw"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "${var.rg-name}-app-gw-ip-config"
    subnet_id = azurerm_subnet.ex1-subnet-app-gw.id
  }
  # Bonus attempt
  waf_configuration {
    enabled          = true
    firewall_mode    = "Detection"
    rule_set_version = 3.2
  }
  ssl_certificate {
    name                = local.cert_tls_ssl
    key_vault_secret_id = azurerm_key_vault_certificate.ex1-cert-appgw.secret_id
  }
  # trusted_root_certificate {
  #   name = local.cert_tls_ssl
  #   key_vault_secret_id = azurerm_key_vault_certificate.ex1-cert-appgw.secret_id
  # }
  frontend_ip_configuration {
    name = local.frontend_ip_configuration_name
    # No public ip ?
  }
  frontend_port {
    name = local.frontend_ip_configuration_name
    port = 443
  }
  backend_address_pool {
    name = local.http_setting_name
    # ip_addresses = [ azurerm_network_interface.ex1-nic-vm. ] # doing this with another resource
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
    frontend_ip_configuration_name = "${var.rg-name}-app-gw-front-ip-name"
    frontend_port_name             = "${var.rg-name}-app-gw-front-port-name"
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
    identity_ids = [azurerm_user_assigned_identity.ex1-app-gw-ass-iden.id]
  }

  #ensuring the cert is ready to be utilized
  depends_on = [azurerm_key_vault.ex1-akv, azurerm_user_assigned_identity.ex1-app-gw-ass-iden, azurerm_key_vault_certificate.ex1-cert-appgw]
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "ex1-app-gw-nic-asso" {
  network_interface_id    = azurerm_network_interface.ex1-nic-vm.id
  ip_configuration_name   = "${var.rg-name}-vm-nic-app-gw-asso"
  backend_address_pool_id = tolist(azurerm_application_gateway.ex1-app-gw.backend_address_pool).0.id
}


#------------------------ AKV associated resources ----------------------------------------------
resource "azurerm_key_vault" "ex1-akv" {
  name                      = "${var.rg-name}-akv"
  resource_group_name       = azurerm_resource_group.ex1.name
  location                  = azurerm_resource_group.ex1.location
  sku_name                  = "standard"
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization = true
}

data "azurerm_role_definition" "keyvault-cert-user" {
  name = "Key Vault Certificate User"
}

resource "azurerm_role_assignment" "app-gw-kv-role" {
  scope                = azurerm_key_vault.ex1-akv.id
  role_definition_name = data.azurerm_role_definition.keyvault-cert-user.name
  principal_id         = azurerm_user_assigned_identity.ex1-app-gw-ass-iden.id
}

# this is specifically for when creating the sql db that it then puts the connection key into the AKV
resource "azurerm_key_vault_access_policy" "ex1-akv-acc-pol-tf" {
  key_vault_id = azurerm_key_vault.ex1-akv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = ["Create", "Update"]
}

resource "azurerm_key_vault_secret" "ex1-akv-db-secret" {
  name         = "${var.rg-name}-db-secret"
  value        = azurerm_mssql_server.ex1-sql-server.administrator_login_password
  key_vault_id = azurerm_key_vault.ex1-akv.id
  # to ensure the connection secret string is created after the value is generated
  depends_on = [azurerm_mssql_database.ex1-sql-db]
}

resource "azurerm_key_vault_certificate" "ex1-cert-appgw" {
  name         = "${var.rg-name}-cert-appgw"
  key_vault_id = azurerm_key_vault.ex1-akv.id

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
  }
}