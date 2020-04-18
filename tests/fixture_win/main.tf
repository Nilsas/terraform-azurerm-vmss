module "vmss_win" {
  source                  = "../../"
  prefix                  = local.prefix
  resource_group_name     = azurerm_resource_group.rg_win.name
  virtual_network_name    = azurerm_virtual_network.vnet_win.name
  subnet_name             = azurerm_subnet.subnet_win.name
  flavour                 = "win"
  instance_count          = 2
  admin_username          = var.admin_user
  admin_password          = var.admin_pass
  tags                    = azurerm_resource_group.rg_win.tags
  load_balance            = true
  load_balanced_port_list = [80,443]
  enable_nat              = true
}