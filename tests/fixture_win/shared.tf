provider "azurerm" {
  version = ">= 2.8.0"

  features {}
}

locals {
  prefix = format("tf%s", lower(random_id.id.b64_url))
}

data "http" "ip" {
  url = "https://api.ipify.org/"
}

resource "random_id" "id" {
  byte_length = 1
}

resource "azurerm_resource_group" "rg_win" {
  location = "westeurope"
  name     = format("%s-rg", local.prefix)
  tags     = {
    EnvironmentType = "Development"
  }
}

resource "azurerm_virtual_network" "vnet_win" {
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg_win.location
  name                = format("%s-vnet", local.prefix)
  resource_group_name = azurerm_resource_group.rg_win.name
  tags                = azurerm_resource_group.rg_win.tags
}

resource "azurerm_subnet" "subnet_win" {
  address_prefixes     = ["10.10.0.0/16"]
  name                 = format("%s-subnet", local.prefix)
  resource_group_name  = azurerm_resource_group.rg_win.name
  virtual_network_name = azurerm_virtual_network.vnet_win.name
}

resource "azurerm_network_security_group" "nsg_win" {
  resource_group_name = azurerm_resource_group.rg_win.name
  location            = azurerm_resource_group.rg_win.location
  name                = format("%s-nsg", local.prefix)
}

resource "azurerm_subnet_network_security_group_association" "nsg_win" {
  subnet_id                 = azurerm_subnet.subnet_win.id
  network_security_group_id = azurerm_network_security_group.nsg_win.id
}

resource "azurerm_network_security_rule" "agent_win" {
  name                        = "allow_all_in_from_agent"
  resource_group_name         = azurerm_resource_group.rg_win.name
  network_security_group_name = azurerm_network_security_group.nsg_win.name
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = data.http.ip.body
  destination_address_prefix  = "*"
}
