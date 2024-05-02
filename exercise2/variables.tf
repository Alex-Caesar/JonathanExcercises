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