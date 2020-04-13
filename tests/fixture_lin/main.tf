provider "azurerm" {
  version = ">= 2.0.0"

  features {
    virtual_machine_scale_set {
      roll_instances_when_required = false
    }
  }
}

resource "azurerm_resource_group" "rg" {
  location = "westeurope"
  name     = "terraform-test-rg"
  tags = {
    EnvironmentType = "Development"
  }
}

module "vmss" {
  source                  = "../../"
  prefix                  = "nil"
  flavour                 = "lin"
  instance_count          = 2
  load_balance            = true
  load_balanced_port_list = [80]
  ssh_key_type            = "Generated"
  resource_group_name     = azurerm_resource_group.rg.name
  admin_username          = "batman"
  tags                    = azurerm_resource_group.rg.tags
}

output "ssh_pub_key" {
  value = module.vmss.ssh_key_public
}

output "ssh_priv_key" {
  value = module.vmss.ssh_key_private
  sensitive = true
}

data "external" "list_vmss_ips" {
  program = ["pwsh", "-Command", "az", "vmss", "list-instance-connection-info",
    "-g", "terraform-test-rg", "--name", "nil-vmss",
  ]
  depends_on = [module.vmss.vmss]
}

output "ssh_conn_info" {
  value = data.external.list_vmss_ips.result
}