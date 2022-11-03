resource "azurerm_network_interface" "this" {
  name                = var.traffic_gen.name
  location            = var.location
  resource_group_name = var.traffic_gen.resource_group
  ip_configuration {
    name                          = var.traffic_gen.name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.traffic_gen.private_ip
  }
  tags = var.common_tags
}

resource "azurerm_virtual_machine" "this" {
  name                          = var.traffic_gen.name
  location                      = var.location
  resource_group_name           = var.resource_group
  network_interface_ids         = [azurerm_network_interface.this.id]
  delete_os_disk_on_termination = true
  vm_size                       = "Standard_B1ls"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = var.traffic_gen.name
    create_option = "FromImage"
    caching       = "ReadWrite"
  }


  os_profile {
    computer_name  = var.traffic_gen.name
    admin_username = "workload_user"
    admin_password = var.workload_password
    custom_data    = data.cloudinit_config.this.rendered
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = var.common_tags
}


data "cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/../ubuntu-traffic-gen.tpl",
      {
        name     = var.traffic_gen.name
        internal = join(",", var.traffic_gen.internal)
        interval = var.traffic_gen.interval
        password = var.workload_password
    })
  }
}

resource "azurerm_network_security_group" "this" {
  name                = var.traffic_gen.name
  resource_group_name = var.resource_group
  location            = var.location
  tags                = var.common_tags
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_network_security_rule" "this_http" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "http"
  priority                    = 100
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "80"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "this_ssh" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "ssh"
  priority                    = 110
  protocol                    = "Tcp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.this.name
}

resource "azurerm_network_security_rule" "this_icmp" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "icmp"
  priority                    = 120
  protocol                    = "Icmp"
  source_port_range           = "*"
  source_address_prefix       = "*"
  destination_port_range      = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.this.name
}
