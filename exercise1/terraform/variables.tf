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
  description = "The password for the msSQL server"
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

variable "vm_size" {
  type        = string
  default     = "Standard_B1s"
  description = "virtual machine vm_size"
}

variable "vm_storage_account_type" {
  type        = string
  default     = "Standard_LRS"
  description = "The storagem account type for the vm"
}

variable "vm_create_option" {
  type        = string
  default     = "fromImage"
  description = "virtual machine fromImage"
}

variable "vm_caching" {
  type        = string
  default     = "ReadWrite"
  description = "virtual machine caching"
}

variable "vm_os_type" {
  type        = string
  default     = "Linux"
  description = "virtual machine os_type"
}

variable "vm_publisher" {
  type        = string
  default     = "Canonical"
  description = "virtual machine publisher"
}

variable "vm_offer" {
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
  description = "virtual machine offer"
}

variable "vm_sku" {
  type        = string
  default     = "22_04-lts"
  description = "virtual machine sku"
}

variable "vm_version" {
  type        = string
  default     = "latest"
  description = "virtual machine version"
}

variable "nginxConfig" {
  type        = string
  default     = "nginxSetup.bash"
  description = "A ref to a script that is run on the vm to setup and configure nginx"
}

variable "web_serve_msg" {
  type        = string
  default     = "Welcome :)"
  description = "Write something fun!"
}