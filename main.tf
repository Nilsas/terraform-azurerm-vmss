provider "azurerm" {
  version = ">=2.0"

  features {
    virtual_machine_scale_set {
      roll_instances_when_required = false
    }
  }
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  address_space       = [var.address_space]
  location            = data.azurerm_resource_group.rg.location
  name                = "${var.prefix}-vnet"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  address_prefix       = var.address_space
  name                 = "${var.prefix}-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_public_ip" "pip" {
  count               = var.load_balance ? 1 : 0
  location            = data.azurerm_resource_group.rg.location
  name                = "${var.prefix}-pip"
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_lb" "lb" {
  count               = var.load_balance ? 1 : 0
  location            = data.azurerm_resource_group.rg.location
  name                = "${var.prefix}-lb"
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${var.prefix}-ip-config"
    public_ip_address_id = element(azurerm_public_ip.pip.*.id, count.index)
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  count               = var.load_balance ? 1 : 0
  loadbalancer_id     = element(azurerm_lb.lb.*.id, count.index)
  name                = "${var.prefix}-backend-pool"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_lb_probe" "probe" {
  count               = var.load_balance ? 1 : 0
  name                = "${var.prefix}-lb-probe"
  resource_group_name = data.azurerm_resource_group.rg.name
  loadbalancer_id     = element(azurerm_lb.lb.*.id, count.index)
  port                = var.probe_port
}

resource "azurerm_linux_virtual_machine_scale_set" "lin_vmss" {
  name                = "${var.prefix}-vmss"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = var.vm_size
  instances           = var.instance_count
  admin_username      = "joker"
  tags                = var.tags

  admin_ssh_key {
    username   = "joker"
    public_key = file("./id_rsa.pub")
  }

  source_image_reference {
    publisher = var.linux_distro_list[lower(var.linux_distro)]["publisher"]
    offer     = var.linux_distro_list[lower(var.linux_distro)]["offer"]
    sku       = var.linux_distro_list[lower(var.linux_distro)]["sku"]
    version   = var.linux_distro_list[lower(var.linux_distro)]["version"]
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.prefix}-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = list(azurerm_lb_backend_address_pool.pool.id)
    }
  }
}

resource "azurerm_windows_virtual_machine_scale_set" "lin_vmss" {
  name                = "${var.prefix}-vmss"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard_B2s"
  instances           = 2
  admin_username      = "joker"
  tags                = var.tags

  admin_ssh_key {
    username   = "joker"
    public_key = file("./id_rsa.pub")
  }

  source_image_reference {
    publisher = var.win_distro_list[lower(var.win_distro)]["publisher"]
    offer     = var.win_distro_list[lower(var.win_distro)]["offer"]
    sku       = var.win_distro_list[lower(var.win_distro)]["sku"]
    version   = var.win_distro_list[lower(var.win_distro)]["version"]
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.prefix}-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = list(azurerm_lb_backend_address_pool.pool.id)
    }
  }
}
