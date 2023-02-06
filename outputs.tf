output "vnet_id" {
  value = "${module.vnet.vnet_id}"
}

output "tidb" {
  value = "${join("\n", module.vm_tidb.*.network_interface_private_ip)}"
}

output "tikv" {
  value = "${join("\n", module.vm_tikv.*.network_interface_private_ip)}"
}

output "pd" {
  value = "${join("\n", module.vm_pd.*.network_interface_private_ip)}"
}

output "monitor" {
  value = "${join("\n", module.vm_monitor.*.network_interface_private_ip)}"
}

output "ticdc" {
  value = "${join("\n", module.vm_ticdc.*.network_interface_private_ip)}"
}

output "bastion_ip" {
  value = "${join("\n", data.azurerm_public_ip.bastion.*.ip_address)}"
}

# tidb_bastion keypair private key
output "tidb_bastion_keypair_private_key" {
  value = "${resource.tls_private_key.bastion_ssh.private_key_openssh}"
  sensitive = true
}
# 
output "tidb_database_keypair_private_key" {
  value = "${resource.tls_private_key.database_ssh.private_key_openssh}"
  sensitive = true
}
