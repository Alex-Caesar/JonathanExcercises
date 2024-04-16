variable "rg_name" {
  type        = string
  default     = "exercise1"
  description = "The name to give the resource group that will be cat for other resource names."
  sensitive   = false
}

variable "rg_location" {
  type        = string
  default     = "westus"
  description = "The location of the resource group and subsequent assets or resources."
  sensitive   = false
}

variable "db_admin" {
  type        = string
  default     = "dbadmin"
  description = "The username for the msSQL server"
  sensitive   = true
}

variable "db_password" {
  type        = string
  default     = "Complex6DbPassw0rd!"
  description = "The passqord for the msSQL server"
  sensitive   = true
}

variable "vm_name" {
  type        = string
  default     = "CaesarVm"
  description = "The name of the virtual machine"
  sensitive   = false
}

variable "vm_admin" {
  type        = string
  default     = "vmadmin"
  description = "The username for the vm"
  sensitive   = true
}

variable "vm_password" {
  type        = string
  default     = "Complex6VmPassw0rd!"
  description = "The passqord for the vm"
  sensitive   = true
}

variable "nginxConfig" {
  type        = string
  default     = "nginxSetup.bash"
  description = "A ref to a script that is run on the vm to setup and configure nginx"
}