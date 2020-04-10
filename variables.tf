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

variable "load_balanced_port_list" {
  type        = list(number)
  default     = []
  description = "List of ports to be forwarded through load balancer to VMs"
}

variable "load_balancer_probe_port" {
  type        = number
  default     = 80
  description = "Port used to health probe from load balancer. Defaults to 80"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "What size your VMs will be"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "This decides how many VM instance should be spun up"
}

variable "additional_data_disk_capacity_list" {
  type        = list(number)
  default     = []
  description = "A list of additional disk capacities in GB to add to each instance"
}

variable "additional_data_disk_storage_account_type" {
  type        = string
  default     = "Standard_LRS"
  description = "Storage account types for additional data disks. Possible values are: Standard_LRS, StandardSSD_LRS, Premium_LRS"
}

variable "os_disk_storage_account_type" {
  type        = string
  default     = "StandardSSD_LRS"
  description = "Storage account types OS disks. Possible values are: Standard_LRS, StandardSSD_LRS, Premium_LRS"
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
  type        = string
  default     = "centos8"
  description = "Variable to pick an OS flavour for Linux based VMSS possible values include: centos8, ubuntu1804"
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
  type        = string
  default     = "wincore"
  description = "Variable to pick an OS flavour for Windows based VMSS possible values include: winserver, wincore, winsql"
}

variable "ssh_key_type" {
  type        = string
  default     = "FilePath"
  description = "Method for passing the SSH key into Linux VMSS. Generated will create a new SSH key pair in terraform. Possible values include: Generated, Filepath. Defaults to FilePath"
}

variable "admin_ssh_key_data" {
  type        = string
  default     = ""
  description = "Public SSH key used for VMSS"
}

variable "admin_username" {
  type        = string
  default     = "batman"
  description = "Username for administration access within VMSS"
}

variable "admin_password" {
  type        = string
  default     = ""
  description = "Password for administration access within VMSS"
}
