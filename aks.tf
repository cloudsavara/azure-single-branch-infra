provider "azurerm" {
    client_id       =   var.client_id
    client_secret   =   var.client_secret
    subscription_id =   var.subscription_id
    tenant_id       =   var.tenant_id
    features {}
}

# Create a resource group if it doesn't exist
data "azurerm_resource_group" "myterraformgroup" {
    name     = "packer"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "aks-vnet"
  location            = data.azurerm_resource_group.myterraformgroup.location
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "aksnodes"
  resource_group_name  = data.azurerm_resource_group.myterraformgroup.name
  address_prefixes       = ["10.1.0.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = var.cluster-name
  location            = data.azurerm_resource_group.myterraformgroup.location
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  dns_prefix          = "tf-aks"
default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.subnet.id
  }
service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }
role_based_access_control {
        enabled = true
    }
}

