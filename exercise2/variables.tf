#  BASE
variable "rg_name" {
  type        = string
  default     = "exercise2"
  description = "The name to give the resource group that will be cat for other resource names."
  sensitive   = false
}
variable "rg_location" {
  type        = string
  default     = "westus"
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
  description = "The password for the PSQL server"
  sensitive   = true
}
variable "psql_sku" {
  type        = string
  default     = "B_Gen4_1"
  description = "The sku for the PSQL server"
}
variable "psql_ver" {
  type        = string
  default     = "11"
  description = "The version for the PSQL server"
}
variable "psql_store_mb" {
  type        = string
  default     = "5120"
  description = "The storage in mb for the PSQL server"
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
  default     = "1"
  description = "The default node pool count for the AKS"
}
variable "aks_default_np_size" {
  type        = string
  default     = "Standard_D2_V2"
  description = "The default node pool vm size for the AKS"
}
variable "aks_ingress_name" {
  type        = string
  default     = "aksingress"
  description = "The name ingress application gateway for the AKS"
}