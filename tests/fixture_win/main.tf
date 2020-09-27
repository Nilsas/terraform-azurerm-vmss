module "vmss_win" {
  source                  = "../../"
  prefix                  = local.prefix
  resource_group_name     = azurerm_resource_group.rg_win.name
  virtual_network_name    = azurerm_virtual_network.vnet_win.name
  subnet_name             = azurerm_subnet.subnet_win.name
  overprovision           = false
  flavour                 = "win"
  win_distro              = "winserver"
  instance_count          = 2
  admin_username          = random_pet.username.id
  admin_password          = random_password.password.result
  tags                    = azurerm_resource_group.rg_win.tags
  load_balance            = true
  load_balanced_port_list = [80, 443]
  enable_nat              = true
}

resource "random_pet" "username" {}

resource "random_password" "password" {
  length  = 16
  special = true
}

resource "null_resource" "delay" {
  // Might want to wait until Azure is done provisioning the instances
  provisioner "local-exec" {
    command     = "Start-Sleep 60"
    interpreter = ["pwsh", "-Command"]
  }
  depends_on = [module.vmss_win.vmss]
}

data "external" "list_win_vmss_ips" {
  program    = [
    "pwsh",
    "-Command",
    "az",
    "vmss",
    "list-instance-connection-info",
    "-g",
    azurerm_resource_group.rg_win.name,
    "--name",
    "${local.prefix}-vmss",
  ]
  depends_on = [null_resource.delay]
}

output "winrm_conn_info" {
  value = data.external.list_win_vmss_ips.result
}

output "winrm_user" {
  value = random_pet.username.id
}

output "winrm_pass" {
  value     = random_password.password.result
  sensitive = true
}