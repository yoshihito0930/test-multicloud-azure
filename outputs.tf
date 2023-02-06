output "vnet_id" {
  value = "${module.vnet.vnet_id}"
}

# output "tidb" {
#   value = "${join("\n", module.ec2_internal_tidb.*.private_ip)}"
# }
# 
# output "tikv" {
#   value = "${join("\n", module.ec2_internal_tikv.*.private_ip)}"
# }
# 
# output "pd" {
#   value = "${join("\n", module.ec2_internal_pd.*.private_ip)}"
# }
# 
# output "monitor" {
#   value = "${join("\n", module.ec2_internal_monitor.*.private_ip)}"
# }
# 
# output "ticdc" {
#   value = "${join("\n", module.ec2_internal_ticdc.*.private_ip)}"
# }

output "bastion_ip" {
  value = "${join("\n", module.vm_bastion.*.network_interface_private_ip)}"
}

# tidb_bastion keypair private key
output "tidb_bastion_keypair_private_key" {
  value = "${resource.tls_private_key.bastion_ssh.private_key_openssh}"
  sensitive = true
}
