# # ***************************  AKS related resources ************************************

# __________________________  Kubernetes ________________________________________

# Networking
# https://stackoverflow.com/questions/69158600/terraform-how-to-find-azure-kubernetes-aks-vnet-id-for-network-peering
resource "azurerm_virtual_network" "ex2_aks_vnet" {
  name                = "aks-vnet"
  location            = azurerm_resource_group.ex2.location
  resource_group_name = azurerm_resource_group.ex2.name
  address_space       = ["10.254.0.0/16"]
}
resource "azurerm_subnet" "ex2_aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_aks_vnet.name
  address_prefixes     = ["10.254.1.0/24"]
}

# AKS
resource "azurerm_kubernetes_cluster" "ex2_aks" {
  name                = "${var.rg_name}-aks-${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location
  dns_prefix          = var.aks_dns_prefix
  sku_tier            = "Standard"

  default_node_pool {
    name           = var.aks_default_np_name
    node_count     = var.aks_default_np_count
    vm_size        = var.aks_default_np_size
    vnet_subnet_id = azurerm_subnet.ex2_aks_subnet.id

    temporary_name_for_rotation = "tempaksnp"
  }

  network_profile {
    network_plugin = "azure"
  }

  node_resource_group = "${azurerm_resource_group.ex2.name}_aks_rg"

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.ex2_app_gw.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# __________________________  Container Registry ________________________________________
# Private Endpointand networking

resource "azurerm_subnet" "ex2_subnet_acr" {
  name                 = "${var.rg_name}_subnet_acr"
  resource_group_name  = azurerm_resource_group.ex2.name
  virtual_network_name = azurerm_virtual_network.ex2_vnet.name
  address_prefixes     = ["10.0.40.0/24"]
}

resource "azurerm_private_dns_zone" "ex2_priv_dns_zone_acr" {
  name                = "privatelink.azurecr.io${var.rg_location}.data.privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.ex2.name
}
resource "azurerm_private_dns_zone_virtual_network_link" "ex2_priv_dns_z_net_link_acr" {
  name                  = "${var.rg_name}_priv_dns_z_net_link_acr"
  resource_group_name   = azurerm_resource_group.ex2.name
  private_dns_zone_name = azurerm_private_dns_zone.ex2_priv_dns_zone_acr.name
  virtual_network_id    = azurerm_virtual_network.ex2_vnet.id
}

resource "azurerm_private_endpoint" "ex2_acr_private_end" {
  name                = "${var.rg_name}_acr_private_end"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  subnet_id = azurerm_subnet.ex2_subnet_acr.id

  private_service_connection {
    name                           = "${var.rg_name}_acr_private_serv_conn"
    private_connection_resource_id = azurerm_container_registry.ex2_acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.rg_name}_private_dns_zg_acr"
    private_dns_zone_ids = [azurerm_private_dns_zone.ex2_priv_dns_zone_acr.id]
  }
}

# ACR
resource "azurerm_container_registry" "ex2_acr" {
  name                = "${var.rg_name}acr${random_integer.number.result}"
  resource_group_name = azurerm_resource_group.ex2.name
  location            = azurerm_resource_group.ex2.location

  sku                           = "Premium"
  public_network_access_enabled = false
  admin_enabled                 = false
}
resource "azurerm_role_assignment" "ex2_acr_role" {
  principal_id                     = azurerm_kubernetes_cluster.ex2_aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.ex2_acr.id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_kubernetes_cluster.ex2_aks]
}
# # tf https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_task
# # need cache rule https://learn.microsoft.com/en-us/azure/container-registry/tutorial-artifact-cache
# resource "azurerm_container_registry_task" "ex2_acr_task" {
#   name                  = "${var.rg_name}-acr-task-pub-img-gitlabee"
#   container_registry_id = azurerm_container_registry.ex2_acr.id
#   platform {
#     os = "Linux"
#   }
#   docker_step {
#     dockerfile_path      = "Dockerfile"
#     context_path         = "https://gitlab.com/gitlab-org/omnibus-gitlab/-/blob/master/docker/Dockerfile"
#     context_access_token = "<github personal access token>"
#     image_names          = ["helloworld:{{.Run.ID}}"]
#     cache_enabled        = true
#   }
# }