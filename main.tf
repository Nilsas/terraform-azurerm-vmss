provider "azurerm" {
  version = "2.0"

  features {
    virtual_machine_scale_set {
      roll_instances_when_required = false
    }
  }
}

resource "azurerm_resource_group" "rg" {
  location = "westeurope"
  name = "${var.prefix}-rg"
  tags = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  address_space = [
    "12.10.0.0/16"]
  location = azurerm_resource_group.rg.location
  name = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  tags = var.tags
}

resource "azurerm_subnet" "subnet" {
  address_prefix = "12.10.10.0/28"
  name = "${var.prefix}-subnet"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_public_ip" "pip" {
  location = azurerm_resource_group.rg.location
  name = "${var.prefix}-pip"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Dynamic"
}

resource "azurerm_lb" "lb" {
  location = azurerm_resource_group.rg.location
  name = "${var.prefix}-lb"
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name = "${var.prefix}-ip-config"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name = "${var.prefix}-backend-pool"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_probe" "probe" {
  name = "${var.prefix}-lb-probe"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.lb.id
  port = 3200
}

resource "azurerm_linux_virtual_machine_scale_set" "lin_vmss" {
  name = "${var.prefix}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku = "Standard_B2s"
  instances = 2
  admin_username = "joker"
  tags = var.tags

  admin_ssh_key {
    username = "joker"
    public_key = file("./id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching = "ReadWrite"
  }

  network_interface {
    name = "${var.prefix}-nic"
    primary = true

    ip_configuration {
      name = "internal"
      primary = true
      subnet_id = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = list(azurerm_lb_backend_address_pool.pool.id)
    }
  }
}