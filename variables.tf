variable "location" {
  type        = string
  default     = "westeurope"
  description = "This variable will point all resource into one Azure location"
}

variable "resource_group_name" {
  type        = string
  default     = "my-resource-group"
  description = "This will tell us to which resource group we need to deploy the resources of this module"
}

variable "address_space" {
  type        = string
  default     = "10.10.0.0/16"
  description = "This is to create a Vnet and Subnet for our Scale Set"
}

variable "prefix" {
  type        = string
  default     = "my-prefix"
  description = "This variable is used to unify all resource naming within this module"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "This variable is used to refference same tags through all resources"
}

variable "load_balance" {
  type        = bool
  default     = false
  description = "This ether enables or disabels the load balancer building"
}

variable "probe_port" {
  type        = string
  default     = "80"
  description = "If load_balancer is set to true it will need a port to probe in order for load balancer to work"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "This desides what size your VMs will be"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "This decides how many VM instance should be spun up"
}

variable "flavour" {
  type        = string
  default     = "linux"
  description = "This is needed to decide which flavour of VMSS to deploy Windows or Linux"
}


variable "linux_distro_list" {
  type = map(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  }))

  default = {
    ubuntu1804 = {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
    }

    centos8 = {
      publisher = "OpenLogic"
      offer     = "CentOS"
      sku       = "8.0"
      version   = "latest"
    }
  }
}

variable "linux_distro" {
  type    = string
  default = "centos8"
}

variable "win_distro_list" {
  type = map(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  }))

  default = {
    winserver = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2019-Datacenter"
      version   = "latest"
    }

    wincore = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2016-Datacenter-Server-Core"
      version   = "latest"
    }

    winsql = {
      publisher = "MicrosoftSQLServer"
      offer     = "SQL2017-WS2016"
      sku       = "Express"
      version   = "latest"
    }
  }
}

variable "win_distro" {
  type    = string
  default = "wincore"
}
