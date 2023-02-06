resource "random_id" "id" {
  byte_length = 2
}

locals {
  resource_group = {
    name     = var.resource_group_name
    location = var.location
  }
}

resource "azurerm_availability_set" "example" {
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  name                = "${var.name_prefix}-as"

  platform_update_domain_count = 3
  platform_fault_domain_count  = 3

  tags = var.tags
}

module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "4.0.0"

  use_for_each        = false
  resource_group_name = local.resource_group.name
  vnet_location       = local.resource_group.location
  address_space       = [var.azure_vpc_cidr]
  vnet_name           = "${var.name_prefix}-vnet"
  subnet_names        = [local.bastion_subnet.name, local.app_subnet.name, local.database_subnet.name, local.gateway_subnet.name]
  subnet_prefixes     = [local.bastion_subnet.cidr, local.app_subnet.cidr, local.database_subnet.cidr, local.gateway_subnet.cidr]

  tags = var.tags
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.name_prefix}-bastion"
  location            = local.resource_group.location
  resource_group_name = local.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
data "azurerm_public_ip" "bastion" {
  name                = "${var.name_prefix}-bastion"
  resource_group_name = local.resource_group.name
}

resource "tls_private_key" "bastion_ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}
resource "tls_private_key" "database_ssh" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

module "vm_bastion" {
  source = "Azure/virtual-machine/azurerm"
  version = "0.1.0"

  # common settings
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  image_os                   = "linux"
  os_simple                  = "CentOS" # CentOS:7.5
  os_version                 = "latest"
  availability_set_id        = azurerm_availability_set.example.id
  allow_extension_operations = false
  boot_diagnostics           = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_disk_size
  }

  # bastion settings
  name                       = "${var.name_prefix}-bastion"
  size                       = var.bastion_instance_type
  subnet_id                  = lookup(module.vnet.vnet_subnets_name_id, local.bastion_subnet.name)
  network_security_group_id  = module.network_security_group_bastion.network_security_group_id
  tags                       = var.tags

  new_network_interface = {
    ip_forwarding_enabled = false
    ip_configurations = [
      {
        primary = true
        public_ip_address_id = azurerm_public_ip.bastion.id
      }
    ]
  }
  admin_ssh_keys = [
    {
      public_key = tls_private_key.bastion_ssh.public_key_openssh
      username   = "azureuser"
    }
  ]

  # init ssh private key use database_ssh key
  # fixme: custom_data is not working
  custom_data = base64encode(<<EOF
    #!/bin/bash
    mkdir -p /home/azureuser/.ssh
    chmod 700 /home/azureuser/.ssh
    echo "${tls_private_key.database_ssh.private_key_openssh}" > /home/azureuser/.ssh/id_rsa
    chmod 600 /home/azureuser/.ssh/id_rsa
  EOF
  )
}

resource "azurerm_network_interface_security_group_association" "bastion_as" {
  network_interface_id      = module.vm_bastion.network_interface_id
  network_security_group_id = module.network_security_group_bastion.network_security_group_id
}

module "vm_tidb" {
  source = "Azure/virtual-machine/azurerm"
  version = "0.1.0"
  count = var.tidb_count

  # common settings
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  image_os                   = "linux"
  os_simple                  = "CentOS" # CentOS:7.5
  os_version                 = "latest"
  availability_set_id        = azurerm_availability_set.example.id
  allow_extension_operations = false
  boot_diagnostics           = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_disk_size
  }

  # tidb server settings
  name                       = "${var.name_prefix}-tidb-${count.index}"
  size                       = var.tidb_instance_type
  subnet_id                  = lookup(module.vnet.vnet_subnets_name_id, local.database_subnet.name)
  network_security_group_id  = module.network_security_group_database.network_security_group_id
  tags                       = var.tags

  new_network_interface = {
    ip_forwarding_enabled = false
    ip_configurations = [
      {
        primary = true
      }
    ]
  }
  admin_ssh_keys = [
    {
      public_key = tls_private_key.database_ssh.public_key_openssh
      username   = "azureuser"
    }
  ]
}

resource "azurerm_network_interface_security_group_association" "tidb_as" {
  count = var.tidb_count
  network_interface_id      = module.vm_tidb[count.index].network_interface_id
  network_security_group_id = module.network_security_group_database.network_security_group_id
}

module "vm_pd" {
  source = "Azure/virtual-machine/azurerm"
  version = "0.1.0"
  count = var.pd_count

  # common settings
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  image_os                   = "linux"
  os_simple                  = "CentOS" # CentOS:7.5
  os_version                 = "latest"
  availability_set_id        = azurerm_availability_set.example.id
  allow_extension_operations = false
  boot_diagnostics           = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_disk_size
  }

  # pd server settings
  name                       = "${var.name_prefix}-pd-${count.index}"
  size                       = var.pd_instance_type
  subnet_id                  = lookup(module.vnet.vnet_subnets_name_id, local.database_subnet.name)
  network_security_group_id  = module.network_security_group_database.network_security_group_id
  tags                       = var.tags

  new_network_interface = {
    ip_forwarding_enabled = false
    ip_configurations = [
      {
        primary = true
      }
    ]
  }
  admin_ssh_keys = [
    {
      public_key = tls_private_key.database_ssh.public_key_openssh
      username   = "azureuser"
    }
  ]
  data_disks = [
    {
      name = "pd-data-disk-${count.index}"
      create_option = "Empty"
      attach_setting = {
        lun = 0
        caching = "ReadWrite"        
      }
      storage_account_type = "Standard_LRS"
      disk_size_gb         = var.pd_data_disk_size
    }
  ]
  # mount data disk
  # fixme: custom_data is not working
  custom_data = base64encode(<<EOF
    #!/bin/bash
    mkfs -t ext4 /dev/sdc
    mkdir -p /data
    echo "/dev/sdc /data ext4 defaults,nofail,noatime,nodelalloc 0 2" >> /etc/fstab
    mount -a
    chown -R azureuser:azureuser /data
  EOF
  )
}

resource "azurerm_network_interface_security_group_association" "pd_as" {
  count = var.pd_count
  network_interface_id      = module.vm_pd[count.index].network_interface_id
  network_security_group_id = module.network_security_group_database.network_security_group_id
}

module "vm_tikv" {
  source = "Azure/virtual-machine/azurerm"
  version = "0.1.0"
  count = var.tikv_count

  # common settings
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  image_os                   = "linux"
  os_simple                  = "CentOS" # CentOS:7.5
  os_version                 = "latest"
  availability_set_id        = azurerm_availability_set.example.id
  allow_extension_operations = false
  boot_diagnostics           = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_disk_size
  }

  # tikv server settings
  name                       = "${var.name_prefix}-tikv-${count.index}"
  size                       = var.pd_instance_type
  subnet_id                  = lookup(module.vnet.vnet_subnets_name_id, local.database_subnet.name)
  network_security_group_id  = module.network_security_group_database.network_security_group_id
  tags                       = var.tags

  new_network_interface = {
    ip_forwarding_enabled = false
    ip_configurations = [
      {
        primary = true
      }
    ]
  }
  admin_ssh_keys = [
    {
      public_key = tls_private_key.database_ssh.public_key_openssh
      username   = "azureuser"
    }
  ]
  data_disks = [
    {
      name = "tikv-data-disk-${count.index}"
      create_option = "Empty"
      attach_setting = {
        lun = 0
        caching = "ReadWrite"        
      }
      storage_account_type = var.tikv_data_disk_type
      disk_size_gb         = var.tikv_data_disk_size
    }
  ]
  # mount data disk
  # fixme: custom_data is not working
  custom_data = base64encode(<<EOF
    #!/bin/bash
    yes | mkfs -t ext4 /dev/sdc
    mkdir -p /data
    echo "/dev/sdc /data ext4 defaults,nofail,noatime,nodelalloc 0 2" >> /etc/fstab
    mount -a
    chown -R azureuser:azureuser /data
  EOF
  )
}

resource "azurerm_network_interface_security_group_association" "tikv_as" {
  count = var.tikv_count
  network_interface_id      = module.vm_tikv[count.index].network_interface_id
  network_security_group_id = module.network_security_group_database.network_security_group_id
}


module "vm_ticdc" {
  source = "Azure/virtual-machine/azurerm"
  version = "0.1.0"
  count = var.ticdc_count

  # common settings
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  image_os                   = "linux"
  os_simple                  = "CentOS" # CentOS:7.5
  os_version                 = "latest"
  availability_set_id        = azurerm_availability_set.example.id
  allow_extension_operations = false
  boot_diagnostics           = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_disk_size
  }

  # ticdc server settings
  name                       = "${var.name_prefix}-ticdc-${count.index}"
  size                       = var.pd_instance_type
  subnet_id                  = lookup(module.vnet.vnet_subnets_name_id, local.database_subnet.name)
  network_security_group_id  = module.network_security_group_database.network_security_group_id
  tags                       = var.tags

  new_network_interface = {
    ip_forwarding_enabled = false
    ip_configurations = [
      {
        primary = true
      }
    ]
  }
  admin_ssh_keys = [
    {
      public_key = tls_private_key.database_ssh.public_key_openssh
      username   = "azureuser"
    }
  ]
  data_disks = [
    {
      name = "ticdc-data-disk-${count.index}"
      create_option = "Empty"
      attach_setting = {
        lun = 0
        caching = "ReadWrite"
      }
      storage_account_type = "Standard_LRS"
      disk_size_gb         = var.ticdc_data_disk_size
    }
  ]
  # mount data disk
  # fixme: custom_data is not working
  custom_data = base64encode(<<EOF
    #!/bin/bash
    yes | mkfs -t ext4 /dev/sdc
    mkdir -p /data
    echo "/dev/sdc /data ext4 defaults,nofail,noatime,nodelalloc 0 2" >> /etc/fstab
    mount -a
    chown -R azureuser:azureuser /data
  EOF
  )
}

resource "azurerm_network_interface_security_group_association" "ticdc_as" {
  count = var.ticdc_count
  network_interface_id      = module.vm_ticdc[count.index].network_interface_id
  network_security_group_id = module.network_security_group_database.network_security_group_id
}

module "vm_monitor" {
  source = "Azure/virtual-machine/azurerm"
  version = "0.1.0"
  count = 1

  # common settings
  location                   = local.resource_group.location
  resource_group_name        = local.resource_group.name
  image_os                   = "linux"
  os_simple                  = "CentOS" # CentOS:7.5
  os_version                 = "latest"
  availability_set_id        = azurerm_availability_set.example.id
  allow_extension_operations = false
  boot_diagnostics           = false
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.root_disk_size
  }

  # monitor server settings
  name                       = "${var.name_prefix}-monitor-${count.index}"
  size                       = var.monitor_instance_type
  subnet_id                  = lookup(module.vnet.vnet_subnets_name_id, local.database_subnet.name)
  network_security_group_id  = module.network_security_group_database.network_security_group_id
  tags                       = var.tags

  new_network_interface = {
    ip_forwarding_enabled = false
    ip_configurations = [
      {
        primary = true
      }
    ]
  }
  admin_ssh_keys = [
    {
      public_key = tls_private_key.database_ssh.public_key_openssh
      username   = "azureuser"
    }
  ]
}

resource "azurerm_network_interface_security_group_association" "monitor_as" {
  count = 1
  network_interface_id      = module.vm_monitor[count.index].network_interface_id
  network_security_group_id = module.network_security_group_database.network_security_group_id
}

## make tidb cluster config from template
resource "local_file" "tidb_cluster_config" {
  content = templatefile("${path.module}/files/tiup-topology.yaml.tpl", {
    pd_private_ips: module.vm_pd.*.network_interface_private_ip,
    tidb_private_ips: module.vm_tidb.*.network_interface_private_ip,
    tikv_private_ips: module.vm_tikv.*.network_interface_private_ip,
    ticdc_private_ips: module.vm_ticdc.*.network_interface_private_ip,
    tiflash_private_ips: [],
    monitor_private_ip: element(module.vm_monitor.*.network_interface_private_ip, 0),
  })
  filename = "${path.module}/tiup-topology.yaml"
  file_permission = "0644"
}

resource "null_resource" "bastion-inventory" {
  depends_on = [resource.local_file.tidb_cluster_config]

  # Changes to any instance of the bastion requires re-provisioning
  triggers = resource.local_file.tidb_cluster_config

  provisioner "file" {
    source      = resource.local_file.tidb_cluster_config.filename
    destination = "/home/azureuser/tiup-topology.yaml"

    connection {
      type        = "ssh"
      user        = "azureuser"
      private_key = "${tls_private_key.bastion_ssh.private_key_openssh}"
      host        = element(data.azurerm_public_ip.bastion.*.ip_address, 0)
    }
  }
}
