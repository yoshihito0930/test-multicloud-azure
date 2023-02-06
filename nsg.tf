# network security requestment 
# bastion subnet :
#  * allow inbound 22 from var.bastion_allow_ssh_from
# app/web subnet : 
#  * (todo) allow inbound 80 from app LB
#  * allow inbound 22 from bastion
# database subnet :
#  * allow inbound 4000 from app subnet and gateway subnet
#  * allow inbound 2379 from bastion(tiup)
#  * allow inbound 22 from bastion



# bastion subnet network security group
module "network_security_group_bastion" {
  source                = "Azure/network-security-group/azurerm"
  version               = "4.0.0"
  resource_group_name   = var.resource_group_name
  location              = var.location
  security_group_name   = "${var.name_prefix}-bastion"

  source_address_prefix = var.bastion_allow_ssh_from
  predefined_rules = [
    {
        name     = "SSH"
        priority = "500"
    }
  ]

  tags = var.tags
  depends_on = [module.vnet]
}

# app/web subnet network security group
module "network_security_group_app" {
  source                = "Azure/network-security-group/azurerm"
  version               = "4.0.0"
  resource_group_name   = var.resource_group_name
  location              = var.location
  security_group_name   = "${var.name_prefix}-app"

  source_address_prefix = [local.bastion_subnet.cidr]
  predefined_rules = [
    {
        name     = "SSH"
        priority = "500"
    }
  ]

  tags = var.tags
  depends_on = [module.vnet]
}

# database subnet network security group
module "network_security_group_database" {
  source                = "Azure/network-security-group/azurerm"
  version               = "4.0.0"
  resource_group_name   = var.resource_group_name
  location              = var.location
  security_group_name   = "${var.name_prefix}-database"

  source_address_prefix = [local.bastion_subnet.cidr]
  predefined_rules = [
    {
        name     = "SSH"
        priority = "500"
    }
  ]

  custom_rules = [
    {
      name                    = "${var.name_prefix}-database-allow-inbound-4000"
      priority                = 200
      direction               = "Inbound"
      access                  = "Allow"
      protocol                = "Tcp"
      source_port_range       = "*"
      destination_port_range  = "4000"
      source_address_prefixes = [local.app_subnet.cidr, local.gateway_subnet.cidr]
      description             = "description-tidb"
    },
    {
      name                    = "${var.name_prefix}-database-allow-tiup"
      priority                = 201
      direction               = "Inbound"
      access                  = "Allow"
      protocol                = "Tcp"
      source_port_range       = "*"
      destination_port_range  = "2379"
      source_address_prefixes = [local.bastion_subnet.cidr]
      description             = "description-tidb-pd"
    },
  ]

  tags = var.tags
  depends_on = [module.vnet]
}

# TODO : Associate app NSG and app Subnet
#resource "azurerm_subnet_network_security_group_association" "web_subnet_nsg_associate" {
#  depends_on = [ azurerm_network_security_rule.web_nsg_rule_inbound] # Every NSG Rule Association will disassociate NSG from Subnet and Associate it, so we associate it only after NSG is completely created - Azure Provider Bug https://github.com/terraform-providers/terraform-provider-azurerm/issues/354  
#  subnet_id                 = azurerm_subnet.websubnet.id
#  network_security_group_id = azurerm_network_security_group.web_subnet_nsg.id
#}

