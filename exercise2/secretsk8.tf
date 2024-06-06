# #_________________________________ K8's data _____________________________________________________________
# data "azurerm_kubernetes_cluster" "cluster" {
#   name                = azurerm_kubernetes_cluster.ex2_aks.name
#   resource_group_name = azurerm_resource_group.ex2.name
#   depends_on          = [azurerm_kubernetes_cluster.ex2_aks]
# }

# provider "kubernetes" {
#   host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
#   client_certificate     = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate)
#   client_key             = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.client_key)
#   cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
# }

# Secrets
# resource "kubernetes_secret" "psql_password" {
#   metadata {
#     name = "psql-pword"
#   }

#   data = {
#     password = var.psql_password
#   }

#   type = "Opaque"

#   depends_on = [azurerm_kubernetes_cluster.ex2_aks]
# }

# resource "kubernetes_secret" "gitlab_password" {
#   metadata {
#     name = "gitlab-pword"
#   }

#   data = {
#     password = var.gitlab_password
#   }

#   type = "Opaque"

#   depends_on = [azurerm_kubernetes_cluster.ex2_aks]
# }
