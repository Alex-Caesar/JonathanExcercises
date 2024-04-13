variable "rg-name" {
  type        = string
  default     = "exercise1"
  description = "The name to give the resource group that will be cat for other resource names."
  sensitive   = false
}

variable "rg-location" {
  type        = string
  default     = "westus"
  description = "The location of the resource group and subsequent assets or resources."
  sensitive   = false
}

variable "db-admin" {
  type        = string
  default     = "admin"
  description = "The username for the msSQL server"
  sensitive   = true
}

variable "db-password" {
  type        = string
  default     = "password"
  description = "The passqord for the msSQL server"
  sensitive   = true
}