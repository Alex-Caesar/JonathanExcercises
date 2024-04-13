variable "rg-name" {
    type = string
  default = "Exercise1"
  description = "The name to give the resource group that will be cat for other resource names."
  sensitive = false
}

variable "rg-location" {
    type = string
  default = "westus"
  description = "The location of the resource group and subsequent assets or resources."
  sensitive = false
}