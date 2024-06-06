#  BASE
variable "rg_name" {
  type        = string
  default     = "exercise2"
  description = "The name to give the resource group that will be cat for other resource names."
  sensitive   = false
}
variable "rg_location" {
  type        = string
  default     = "eastus"
  description = "The location of the resource group and subsequent assets or resources."
  sensitive   = false
}

#  PSQL
variable "psql_admin" {
  type        = string
  default     = "psqladmin"
  description = "The username for the PSQL server"
  sensitive   = true
}
variable "psql_password" {
  type        = string
  description = "The password for the PSQL server. Note: you must create a k8s secret on the cluster with the name psql-pword with a key of password."
  sensitive   = true
}
variable "psql_sku" {
  type        = string
  default     = "B_Standard_B1ms"
  description = "The sku for the PSQL server"
}
variable "psql_ver" {
  type        = string
  default     = "16"
  description = "The version for the PSQL server"
}
variable "psql_store_mb" {
  type        = string
  default     = "32768"
  description = "The storage in mb for the PSQL server"
}
variable "psql_store_tier" {
  type        = string
  default     = "P4"
  description = "The storage tier for the PSQL server"
}
variable "psql_backup_ret" {
  type        = string
  default     = "0"
  description = "The backup retention policy for the PSQL server"
}

# AKV
variable "aks_dns_prefix" {
  type        = string
  default     = "ex2aks"
  description = "The dns prefix for the AKS"
}
variable "aks_default_np_name" {
  type        = string
  default     = "default"
  description = "The default node pool name for the AKS"
}
variable "aks_default_np_count" {
  type        = string
  default     = "2"
  description = "The default node pool count for the AKS"
}
variable "aks_default_np_size" {
  type        = string
  default     = "Standard_D4S_V3"
  description = "The default node pool vm size for the AKS"
}
variable "aks_ingress_name" {
  type        = string
  default     = "aksingress"
  description = "The name ingress application gateway for the AKS"
}

variable "gitlab_password" {
  type        = string
  description = "The password for the GitLab server. Note: you must create a k8s secret on the cluster with the name gitlab-pword with a key of password."
  sensitive   = true
}