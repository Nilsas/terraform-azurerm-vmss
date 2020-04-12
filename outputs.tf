output "ssh_key_public" {
  value = lower(var.ssh_key_type) == "generated" ? tls_private_key.ssh[0].public_key_openssh : null
}

output "ssh_key_private" {
  value = lower(var.ssh_key_type) == "generated" ? tls_private_key.ssh[0].private_key_pem : null
}

output "pip" {
  value = azurerm_public_ip.pip
}