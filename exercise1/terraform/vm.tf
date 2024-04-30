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
  source_address_prefixes     = ["GatewayManager", "AzureLoadBalancer"]
  destination_address_prefix  = azurerm_subnet.ex1_subnet_vm.address_prefixes.0
  resource_group_name         = azurerm_resource_group.ex1.name
  network_security_group_name = azurerm_network_security_group.ex1_vm_netsecg.name
}

resource "azurerm_user_assigned_identity" "ex1_vm_ass_iden" {
  name                = "${var.rg_name}_vm_ass_iden"
  location            = azurerm_resource_group.ex1.location
  resource_group_name = azurerm_resource_group.ex1.name
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

resource "azurerm_network_interface" "ex1_nic_vm" {
  name                = "${var.rg_name}_nic_vm"
  resource_group_name = azurerm_resource_group.ex1.name
  location            = azurerm_resource_group.ex1.location

  ip_configuration {
    name                          = local.vm_nic_ip_name
    subnet_id                     = azurerm_subnet.ex1_subnet_vm.id
    private_ip_address_allocation = "Dynamic"
    # Comment out when SSH is turned off
    # public_ip_address_id = azurerm_public_ip.ex1_vm_pub_ip.id
  }
}

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

  admin_ssh_key {
    username   = var.vm_admin
    public_key = file("./vm.pub.pub")
  }

  source_image_reference {
    publisher = var.vm_publisher
    offer     = var.vm_offer
    sku       = var.vm_sku
    version   = var.vm_version
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ex1_vm_ass_iden.id]
  }

  disable_password_authentication = false

  depends_on = [azurerm_key_vault.ex1_akv]
}

# Extensions

resource "azurerm_virtual_machine_extension" "ex1_vm_extension_akv_grab" {
  name                       = "akv_grab"
  virtual_machine_id         = azurerm_linux_virtual_machine.ex1_vm.id
  publisher                  = "Microsoft.Azure.KeyVault"
  type                       = "KeyVaultForLinux"
  type_handler_version       = "2.0"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "secretsManagementSettings": {
          "pollingIntervalInS": "3600",
          "requireInitialSync": true,
          "certificateStoreLocation": "/tmp/",
          "observedCertificates": [ "${azurerm_key_vault_certificate.ex1_cert_appgw.secret_id}" ]
        },
        "authenticationSettings": {
          "msiEndpoint":  "http://169.254.169.254/metadata/identity/oauth2/token",
          "msiClientId": "${azurerm_user_assigned_identity.ex1_vm_ass_iden.client_id}"
        }
    }
SETTINGS

  depends_on = [azurerm_linux_virtual_machine.ex1_vm, azurerm_network_interface.ex1_nic_vm, azurerm_user_assigned_identity.ex1_vm_ass_iden, azurerm_key_vault_certificate.ex1_cert_appgw]
}

# Custom Script Extension to install NGINX and configure it
resource "azurerm_virtual_machine_extension" "ex1_vm_extension_nginx_setup" {
  name                       = "nginx_setup"
  virtual_machine_id         = azurerm_linux_virtual_machine.ex1_vm.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  automatic_upgrade_enabled  = false
  auto_upgrade_minor_version = false

  settings = <<SETTINGS
    {
        "script": "${base64encode(templatefile(var.nginxConfig, { AKV_NAME = "${azurerm_key_vault.ex1_akv.name}", CERT_NAME = "${azurerm_key_vault_certificate.ex1_cert_appgw.name}" }))}"
    }
SETTINGS

  depends_on = [azurerm_linux_virtual_machine.ex1_vm, azurerm_key_vault_certificate.ex1_cert_appgw, azurerm_virtual_machine_extension.ex1_vm_extension_akv_grab]
}