provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_network_interface" "sql_nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "sql_vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.sql_nic.id]
  vm_size               = var.vm_size
  zones                 = ["1"]

  delete_data_disks_on_termination = true
  delete_os_disk_on_termination    = true

  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2025-WS2025"
    sku       = "stddev-gen2"
    version   = "latest"
  }

  storage_os_disk {
    name          = "${var.vm_name}_OsDisk"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true
  }
}

resource "azurerm_mssql_virtual_machine" "sql_config" {
  virtual_machine_id = azurerm_virtual_machine.sql_vm.id
  sql_license_type   = "PAYG"
}

resource "azurerm_managed_disk" "disk_d" {
  name                 = "${var.vm_name}_DataDisk_D"
  location             = var.location
  resource_group_name  = var.resource_group_name
  disk_size_gb         = var.disk_d_size
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  zone                 = "1"
}

resource "azurerm_managed_disk" "disk_e" {
  name                 = "${var.vm_name}_DataDisk_E"
  location             = var.location
  resource_group_name  = var.resource_group_name
  disk_size_gb         = var.disk_e_size
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  zone                 = "1"
}

resource "azurerm_managed_disk" "disk_f" {
  name                 = "${var.vm_name}_DataDisk_F"
  location             = var.location
  resource_group_name  = var.resource_group_name
  disk_size_gb         = var.disk_f_size
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  zone                 = "1"
}

resource "azurerm_managed_disk" "disk_g" {
  name                 = "${var.vm_name}_DataDisk_G"
  location             = var.location
  resource_group_name  = var.resource_group_name
  disk_size_gb         = var.disk_g_size
  storage_account_type = "PremiumV2_LRS"
  create_option        = "Empty"
  zone                 = "1"
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_d" {
  virtual_machine_id = azurerm_virtual_machine.sql_vm.id
  managed_disk_id    = azurerm_managed_disk.disk_d.id
  lun                = 0
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_e" {
  virtual_machine_id = azurerm_virtual_machine.sql_vm.id
  managed_disk_id    = azurerm_managed_disk.disk_e.id
  lun                = 1
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_f" {
  virtual_machine_id = azurerm_virtual_machine.sql_vm.id
  managed_disk_id    = azurerm_managed_disk.disk_f.id
  lun                = 2
  caching            = "None"
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_g" {
  virtual_machine_id = azurerm_virtual_machine.sql_vm.id
  managed_disk_id    = azurerm_managed_disk.disk_g.id
  lun                = 3
  caching            = "None"
}

resource "azurerm_network_security_group" "sql_nsg" {
  name                = "${var.vm_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "RDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "SQL"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["1433"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "sql_nic_nsg" {
  network_interface_id      = azurerm_network_interface.sql_nic.id
  network_security_group_id = azurerm_network_security_group.sql_nsg.id
}

resource "azurerm_virtual_machine_extension" "disk_init" {
  name                 = "Initialize-Data-Disks"
  virtual_machine_id   = azurerm_virtual_machine.sql_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris = [
      "https://raw.githubusercontent.com/jswelborn/terraform-fdb-uk-sql/main/initialize-disks.ps1",
      "https://raw.githubusercontent.com/jswelborn/terraform-fdb-uk-sql/main/install-and-schedule.ps1"
    ],
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"Start-Sleep -Seconds 60; New-Item -ItemType Directory -Path 'C:\\Temp' -Force; Copy-Item -Path '.\\*' -Destination 'C:\\Temp' -Force; & 'C:\\Temp\\install-and-schedule.ps1'\""
  })
}
