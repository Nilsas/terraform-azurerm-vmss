provider "azurerm" {
  version = ">= 2.0.0"

  features {
    virtual_machine_scale_set {
      roll_instances_when_required = false
    }
  }
}

locals {
  prefix = format("tf%s", lower(random_id.id.id))
}

data "http" "ip" {
  url = "https://api.ipify.org/"
}

resource "random_id" "id" {
  byte_length = 5
}

resource "azurerm_resource_group" "rg" {
  location = "westeurope"
  name     = format("%s-rg", local.prefix)
  tags     = {
    EnvironmentType = "Development"
  }
}

resource "azurerm_virtual_network" "vnet" {
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  name                = format("%s-vnet", local.prefix)
  resource_group_name = azurerm_resource_group.rg.name
  tags                = azurerm_resource_group.rg.tags
}

resource "azurerm_subnet" "subnet" {
  address_prefix       = "10.10.0.0/16"
  name                 = format("%s-subnet", local.prefix)
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

module "vmss" {
  source                  = "../../"
  resource_group_name     = azurerm_resource_group.rg.name
  virtual_network_name    = azurerm_virtual_network.vnet.name
  subnet_name             = azurerm_subnet.subnet.name
  prefix                  = local.prefix
  flavour                 = "lin"
  instance_count          = 2
  load_balance            = true
  load_balanced_port_list = [80]
  ssh_key_type            = "Generated"
  admin_username          = "batman"
  tags                    = azurerm_resource_group.rg.tags
}

resource "azurerm_network_security_group" "nsg" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = format("%s-nsg", local.prefix)
}

resource "azurerm_subnet_network_security_group_association" "nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_security_rule" "local" {
  name                        = "allow_all_in_local_subnet"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = data.http.ip.body
  destination_address_prefix  = "*"
}

output "ssh_pub_key" {
  value = module.vmss.ssh_key_public
}

output "ssh_priv_key" {
  value     = module.vmss.ssh_key_private
  sensitive = true
}

data "external" "list_vmss_ips" {
  program    = [
    "pwsh",
    "-Command",
    "az",
    "vmss",
    "list-instance-connection-info",
    "-g",
    "${azurerm_resource_group.rg.name}",
    "--name",
    "${local.prefix}-vmss",
  ]
  depends_on = [module.vmss.vmss]
}

output "ssh_conn_info" {
  value = data.external.list_vmss_ips.result
}