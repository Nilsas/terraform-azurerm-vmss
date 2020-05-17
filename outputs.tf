output "ssh_key_public" {
  value       = lower(var.ssh_key_type) == "generated" ? tls_private_key.ssh[0].public_key_openssh : null
  description = "Outputs SSH Public Key if you chose Generated SSH Keys"
}

output "ssh_key_private" {
  value       = lower(var.ssh_key_type) == "generated" ? tls_private_key.ssh[0].private_key_pem : null
  description = "Outputs SSH Private Key if you chose Generated SSH Keys"
}

output "pip" {
  value       = azurerm_public_ip.pip
  description = "Outputs full Public IP resource"
}

output "lb" {
  value       = azurerm_lb.lb[*]
  description = "Outputs full Load Balancer resource"
}

output "lbbepool" {
  value       = azurerm_lb_backend_address_pool.pool[*]
  description = "Outputs full Load Balancer Backend Pool resource"
}

output "lbnatpool" {
  value       = azurerm_lb_nat_pool.natpool[*]
  description = "Outputs full Load Balancer NAT Pool resource"
}

output "lbprobe" {
  value       = azurerm_lb_probe.probe[*]
  description = "Outputs full Load Balancecr Probe resource"
}

output "lbrule" {
  value       = azurerm_lb_rule.lb_rule[*]
  description = "Outputs full Load Balancer Rule resource"
}

output "vmss" {
  value       = var.flavour == "linux" || var.flavour == "lin" ? azurerm_linux_virtual_machine_scale_set.lin_vmss : azurerm_windows_virtual_machine_scale_set.win_vmss
  description = "Outputs full Virtual Machine Scale Set resource depending on flavour chose ether Windows or Linux"
}