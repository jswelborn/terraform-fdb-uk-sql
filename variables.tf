variable "vm_name" {
  description = "The name of the virtual machine."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created."
  type        = string
  default     = "UK South"
}

variable "resource_group_name" {
  description = "The name of the resource group where resources will be created."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet where the virtual machine will be deployed."
  type        = string
}

variable "vm_size" {
  description = "The size of the virtual machine."
  type        = string
  default     = "Standard_D8s_v5"
}

variable "admin_username" {
  description = "The administrator username for the virtual machine."
  type        = string
}

variable "admin_password" {
  description = "The administrator password for the virtual machine."
  type        = string
  sensitive   = true
}

variable "disk_d_size" {
  description = "Size of D drive in GB"
  type        = number
  default     = 384
}

variable "disk_e_size" {
  description = "Size of E drive in GB"
  type        = number
  default     = 1024
}

variable "disk_f_size" {
  description = "Size of F drive in GB"
  type        = number
  default     = 1024
}

variable "disk_g_size" {
  description = "Size of G drive in GB"
  type        = number
  default     = 1024
}

variable "disk_h_size" {
  description = "Size of H drive in GB"
  type        = number
  default     = 60
}

variable "subscription_id" {
  description = "The Azure subscription ID where resources will be created."
  type        = string
}

