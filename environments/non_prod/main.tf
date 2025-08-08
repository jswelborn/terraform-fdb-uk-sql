provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "sql_vm" {
  source = "../../modules/sql_vm/"

  vm_name             = var.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disk_d_size         = var.disk_d_size
  disk_e_size         = var.disk_e_size
  disk_f_size         = var.disk_f_size
  disk_g_size         = var.disk_g_size
  disk_h_size         = var.disk_h_size
  subscription_id     = var.subscription_id
}
