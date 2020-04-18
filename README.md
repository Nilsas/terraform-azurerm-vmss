# terraform-azurerm-vmss

[![Build Status](https://dev.azure.com/NilsasFirantas/tf-modules/_apis/build/status/Nilsas.terraform-azurerm-vmss-terratest?branchName=master)](https://dev.azure.com/NilsasFirantas/tf-modules/_build/latest?definitionId=11&branchName=master)

This module builds Windows or Linux based scale set. <br /> 
Optionaly Load Balancer can be provisioned. <br />
Optionaly SSH certificate can be generated on the spot <br />

Prerequisites and tested on:
- Terraform 0.12.24
- Azurerm provider 2.2.0
- (Optional) Tls provider 2.1.1

## Usage (minimal)

```hcl
provider "azurerm" {
  version = ">= 2.0.0"
  features {}
}

locals {
  prefix = "nil"
}

resource "azurerm_resource_group" "rg" {
  location = "westeurope"
  name     = format("%s-rg", local.prefix)
  tags = {
    Environment = "Development"
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

module "vmss_lin" {
  source                  = "github.com/Nilsas/terraform-azurerm-vmss.git"
  prefix                  = local.prefix
  resource_group_name     = azurerm_resource_group.rg.name
  virtual_network_name    = azurerm_virtual_network.vnet.name
  subnet_name             = azurerm_subnet.subnet.name
  flavour                 = "lin"
  instance_count          = 2
  ssh_key_type            = "Generated"
  admin_username          = "batman"
  tags                    = azurerm_resource_group.rg.tags
}

output "ssh_pub_key" {
  value = module.vmss_lin.ssh_key_public
}

output "ssh_priv_key" {
  value     = module.vmss_lin.ssh_key_private
  sensitive = true
}
```

### Light configuration
The above example will build a Linux based (default flavour is CentOS 8) VM scale set in your specified resource group with the tags applied to the resource group <br />
This will not include load balancing as it defaults to false.
SSH Keys will be generated on the go with Terraform TLS provider as `ssh_key_type` is set to "Generated".<br /> 
To acquire the keys you will need to specify outputs with value equal to `module.vmss_lin.ssh_key_public` and `module.vmss_lin.ssh_key_private` (depends on how you called your module obviously).


## Usage (load balancer)

```hcl
resource "azurerm_resource_group" "rg" {
  ...
}
resource "azurerm_virtual_network" "vnet" {
  ...
}

resource "azurerm_subnet" "subnet" {
  ...
}

module "vmss_lin" {
  source                  = "github.com/Nilsas/terraform-azurerm-vmss.git"
  prefix                  = local.prefix
  resource_group_name     = azurerm_resource_group.rg.name
  virtual_network_name    = azurerm_virtual_network.vnet.name
  subnet_name             = azurerm_subnet.subnet.name
  flavour                 = "lin" # same as "linux"
  lin_distro              = "ubuntu1804"
  instance_count          = 2
  ssh_key_type            = "FilePath"
  admin_ssh_key_data      = file("./id_rsa.pub")
  admin_username          = "batman"
  tags                    = azurerm_resource_group.rg.tags
  load_balance            = true
  load_balanced_port_list = [80]
  enable_nat              = true
}
```

`ssh_key_type` set to other than "generated" will require `admin_ssh_key_data` to be set, you can just have a full string here. <br />
`lin_distro` right now can be set only to `ubuntu1804` or `centos8`. Defaults to the later one.
`load_balance` when set to `true` exposes few more variables: `load_balanced_port_list`, `load_balancer_probe_port`, `enable_nat`
`enable_nat` will deploy load balancer nat pool with backend port "22" for linux flavour and with port 5986 for windows flavour

## Usage (Windows with load balancer)

```hcl
resource "azurerm_resource_group" "rg" {
  ...
}
resource "azurerm_virtual_network" "vnet" {
  ...
}

resource "azurerm_subnet" "subnet" {
  ...
}

module "vmss_win" {
  source                  = "github.com/Nilsas/terraform-azurerm-vmss.git"
  prefix                  = local.prefix
  resource_group_name     = azurerm_resource_group.rg.name
  virtual_network_name    = azurerm_virtual_network.vnet.name
  subnet_name             = azurerm_subnet.subnet.name
  flavour                 = "win" # same as "windows"
  win_distro              = "winserver" # valid values "winserver", "winsql", "wincore". Default is "wincore"
  instance_count          = 2
  admin_username          = "batman"
  admin_password          = "S3cr3tu5M@x!mu$"
  tags                    = azurerm_resource_group.rg.tags
  load_balance            = true
  load_balanced_port_list = [80,443]
  enable_nat              = true
}
```

### Tip #1: resource to get instance connection info
Adjust to your own needs
```hcl
data "external" "list_vmss_ips" {
  program = [
    "pwsh",
    "-Command",
    "az",
    "vmss",
    "list-instance-connection-info",
    "-g",
    azurerm_resource_group.rg.name,
    "--name",
    "${local.prefix}-vmss",
  ]
  depends_on = [module.vmss_lin.vmss]
}
```

### Tip #2: To actually be able to connect to any instance there's need to be an NSG
alogside your configuration deploy something like this
```hcl
data "http" "ip" {
  url = "https://api.ipify.org/"
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

resource "azurerm_network_security_rule" "agent" {
  name                        = "allow_all_in_from_agent"
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
```