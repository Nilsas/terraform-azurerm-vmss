# terraform-azurerm-vmss

This module builds Windows or Linux based scale set, with it's own Vnet and Subnet. It can create Load balancing but it is optional.

Prerequisites and tested on:
Terraform 0.12.24
Azurerm provider 2.2.0
(Optional) Tls provider 2.1.1

## Usage

```hcl
provider "azurerm" {
  version = ">= 2.0.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
  location = "westeurope"
  name     = "nil-rg"
  tags = {
    Environment = "Development"
  }
}

module "vmss" {
  source                  = "github.com/Nilsas/terraform-azurerm-vmss.git"
  prefix                  = "nil"
  flavour                 = "lin"
  instance_count          = 2
  ssh_key_type            = "Generated"
  resource_group_name     = azurerm_resource_group.rg.name
  admin_username          = "batman"
  tags                    = azurerm_resource_group.rg.tags
}
```

### Light configuration
The above example will build a Linux based (default flavour is CentOS 8) VM scale set in your specified resource group with the tags applied to the resource group.
This will not include load balancing as it defaults to false.
SSH Keys will be generated on the go with Terraform. To aquire the keys you will need to specify outputs with value equal to `module.vmss.ssh_key_public` and `module.vmss.ssh_key_private` (depends on how you called your module obviously).
