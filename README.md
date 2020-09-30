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

For some weird reason winrm enabling might now always work, I'm investigating pull requests welcome

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
  admin_password          = "S3cr3tu5M@x!mu$"  # Please change this
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

### Tip #2: To actually be able to connect to any instance you should have NSG in place
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

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 2.0.0 |
| tls | ~> 2.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| additional\_data\_disk\_capacity\_list | A list of additional disk capacities in GB to add to each instance | `list(number)` | `[]` | no |
| additional\_data\_disk\_storage\_account\_type | Storage account types for additional data disks. Possible values are: Standard\_LRS, StandardSSD\_LRS, Premium\_LRS | `string` | `"Standard_LRS"` | no |
| admin\_password | Password for administration access within VMSS | `string` | `""` | no |
| admin\_ssh\_key\_data | Public SSH key used for VMSS | `string` | `""` | no |
| admin\_username | Username for administration access within VMSS | `string` | `"batman"` | no |
| enable\_nat | If enabled load balancer nat pool will be created for SSH if flavor is linux and for winrm if flavour is windows | `bool` | `false` | no |
| flavour | This is needed to decide which flavour of VMSS to deploy Windows or Linux | `string` | `"linux"` | no |
| instance\_count | This decides how many VM instance should be spun up | `number` | `1` | no |
| linux\_distro | Variable to pick an OS flavour for Linux based VMSS possible values include: centos8, ubuntu1804 | `string` | `"centos8"` | no |
| linux\_distro\_list | n/a | <pre>map(object({<br>    publisher = string<br>    offer     = string<br>    sku       = string<br>    version   = string<br>  }))</pre> | <pre>{<br>  "centos8": {<br>    "offer": "CentOS",<br>    "publisher": "OpenLogic",<br>    "sku": "8.0",<br>    "version": "latest"<br>  },<br>  "ubuntu1804": {<br>    "offer": "UbuntuServer",<br>    "publisher": "Canonical",<br>    "sku": "18.04-LTS",<br>    "version": "latest"<br>  }<br>}</pre> | no |
| load\_balance | This ether enables or disabels the load balancer building | `bool` | `false` | no |
| load\_balanced\_port\_list | List of ports to be forwarded through load balancer to VMs | `list(number)` | `[]` | no |
| load\_balancer\_probe\_port | Port used to health probe from load balancer. Defaults to 80 | `number` | `80` | no |
| location | This variable will point all resource into one Azure location | `string` | `"westeurope"` | no |
| os\_disk\_storage\_account\_type | Storage account types OS disks. Possible values are: Standard\_LRS, StandardSSD\_LRS, Premium\_LRS | `string` | `"StandardSSD_LRS"` | no |
| overprovision | This means that multiple Virtual Machines will be provisioned and Azure will keep the instances which become available first - which improves provisioning success rates and improves deployment time. You're not billed for these over-provisioned VM's and they don't count towards the Subscription Quota | `bool` | `true` | no |
| prefix | This variable is used to unify all resource naming within this module | `string` | `"my-prefix"` | no |
| resource\_group\_name | This will tell us to which resource group we need to deploy the resources of this module | `string` | `"my-resource-group"` | no |
| ssh\_key\_type | Method for passing the SSH key into Linux VMSS. Generated will create a new SSH key pair in terraform. Possible values include: Generated, Filepath. Defaults to FilePath | `string` | `"FilePath"` | no |
| subnet\_name | This determines the name of subnet for our Scale Set. | `string` | `""` | no |
| tags | This variable is used to refference same tags through all resources | `map(string)` | `{}` | no |
| virtual\_network\_name | This will get the Vnet provided to the module to use for further deployment of resources | `string` | `"my-virtual-network"` | no |
| vm\_size | What size your VMs will be | `string` | `"Standard_B2s"` | no |
| win\_distro | Variable to pick an OS flavour for Windows based VMSS possible values include: winserver, wincore, winsql | `string` | `"wincore"` | no |
| win\_distro\_list | n/a | <pre>map(object({<br>    publisher = string<br>    offer     = string<br>    sku       = string<br>    version   = string<br>  }))</pre> | <pre>{<br>  "wincore": {<br>    "offer": "WindowsServer",<br>    "publisher": "MicrosoftWindowsServer",<br>    "sku": "2016-Datacenter-Server-Core",<br>    "version": "latest"<br>  },<br>  "winserver": {<br>    "offer": "WindowsServer",<br>    "publisher": "MicrosoftWindowsServer",<br>    "sku": "2019-Datacenter",<br>    "version": "latest"<br>  },<br>  "winsql": {<br>    "offer": "SQL2017-WS2016",<br>    "publisher": "MicrosoftSQLServer",<br>    "sku": "Express",<br>    "version": "latest"<br>  }<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| lb | Outputs full Load Balancer resource |
| lbbepool | Outputs full Load Balancer Backend Pool resource |
| lbnatpool | Outputs full Load Balancer NAT Pool resource |
| lbprobe | Outputs full Load Balancecr Probe resource |
| lbrule | Outputs full Load Balancer Rule resource |
| pip | Outputs full Public IP resource |
| ssh\_key\_private | Outputs SSH Private Key if you chose Generated SSH Keys |
| ssh\_key\_public | Outputs SSH Public Key if you chose Generated SSH Keys |
| vmss | Outputs full Virtual Machine Scale Set resource depending on flavour chose ether Windows or Linux |


