output "ssh_key_public" {
  value = lower(var.ssh_key_type) == "generated" ? tls_private_key.ssh[0].public_key_openssh : null
}

output "ssh_key_private" {
  value = lower(var.ssh_key_type) == "generated" ? tls_private_key.ssh[0].private_key_pem : null
}

output "pip" {
  value = azurerm_public_ip.pip
}

output "lbnatpool" {
  value = azurerm_lb_nat_pool.natpool
}

output "vmss" {
  value = var.flavour == "linux" || var.flavour == "lin" ? azurerm_linux_virtual_machine_scale_set.lin_vmss : azurerm_windows_virtual_machine_scale_set.win_vmss
}