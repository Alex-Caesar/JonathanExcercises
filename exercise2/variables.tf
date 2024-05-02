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