# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
data "azurerm_resource_group" "myterraformgroup" {
    name     = "packer"
}

# Locate the existing custom image
data "azurerm_image" "main" {
  name = "mySBPImage"
  resource_group_name = "packer"

}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = data.azurerm_resource_group.myterraformgroup.location
    resource_group_name = data.azurerm_resource_group.myterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = data.azurerm_resource_group.myterraformgroup.location
    resource_group_name = data.azurerm_resource_group.myterraformgroup.name
	

    tags = {
        environment = "Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = data.azurerm_resource_group.myterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = data.azurerm_resource_group.myterraformgroup.location
    resource_group_name          = data.azurerm_resource_group.myterraformgroup.name
    allocation_method            = "Static"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                      = "myNIC"
    location                  = data.azurerm_resource_group.myterraformgroup.location
    resource_group_name       = data.azurerm_resource_group.myterraformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.myterraformnic.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = data.azurerm_resource_group.myterraformgroup.location
    resource_group_name   = data.azurerm_resource_group.myterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size               = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
		    storage_account_type = "Standard_LRS"
    }

    plan {
      name = "centos-75-free"
      product = "centos-75-lts-free"
      publisher = "cognosys"
    }

    source_image_id = data.azurerm_image.main.id
    computer_name  = "myvm"
    admin_username = "azureuser"
    admin_password = "Welcome$123456"
    disable_password_authentication = false

    tags = {
        environment = "Terraform Demo"
    }
}

output "public_ip_address" {
  value = "${azurerm_public_ip.myterraformpublicip.ip_address}"
}