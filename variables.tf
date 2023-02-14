## name prefix
variable "name_prefix" {
  type        = string
  default     = "tidb-test"
  description = "Name prefix"
}

## azure configure

variable "location" {
  type     = string
  default  = "eastus"
  nullable = false
}

variable "resource_group_name" {
  type    = string
  default = "test-tidb"
}

variable "azure_vpc_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "azure VPC CIDR"
}

/*
  subnet cidrの割り当て方針（例）
  192.168.0.0/17      (192.168.128.0 - 192.168.255.255)   : 保留
  192.168.128.0/17    (192.168.128.0 - 192.168.255.255)   : 使う
  192.168.128.0/18    (192.168.128.0 - 192.168.191.255)   :   public
  192.168.128.0/24    (192.168.128.0 - 192.168.128.255)   :     public/first-half/bastion ※
  192.168.129.0       (192.168.129.0 - 192.168.128.255)   :     public/first-half/保留
  192.168.160.0/19    (192.168.160.0 - 192.168.191.255)   :     public/second-half/all-to-app-web ※
  192.168.192.0/18    (192.168.192.0 - 192.168.255.255)   :   private
  192.168.192.0/19    (192.168.192.0 - 192.168.223.255)   :     private/first-half/all-to-database ※
  192.168.224.0/19    (192.168.224.0 - 192.168.255.255)   :     private/second-half/保留
  ...
  192.168.254.0/25    (192.168.254.0 - 192.168.254.127)   :     private/second-half/gateway ※
  192.168.254.128/25  (192.168.254.128 - 192.168.254.255) :     private/second-half/gateway ※
*/

variable "bastion_subnet_cidr" {
  type        = string
  default     = "192.168.128.0/24"
  description = "azure public subnet for bastion"
}

variable "app_subnet_cidr" {
  type        = string
  default     = "192.168.160.0/19"
  description = "azure public subnet for app/web"
}

variable "database_subnet_cidr" {
  type        = string
  default     = "192.168.192.0/19"
  description = "azure private subnet for database"
}

## tidb servers spec

variable "tidb_instance_type" {
 type    = string
 default = "Standard_F2" # production: Standard_F8s_v2
}

variable "tikv_instance_type" {
  type    = string
  default = "Standard_F2" # Standard_L8s_v2
}
variable "tikv_data_disk_type" {
  type    = string
  default = "Standard_LRS" # UltraSSD_LRS
}

variable "pd_instance_type" {
  type    = string
  default = "Standard_F2" # production: Standard_F8s_v2
}

variable "monitor_instance_type" {
  type    = string
  default = "Standard_F2"
}

variable "ticdc_instance_type" {
  type    = string
  default = "Standard_F2" # production: Standard_F8s_v2
}

variable "bastion_instance_type" {
  type    = string
  default = "Standard_F2"
}

## servers disk 

variable "root_disk_size" {
  type    = number
  default = 100
}

variable "tikv_data_disk_size" {
  type    = number
  default = 200
}

variable "tikv_data_disk_throughput" {
  type    = number
  default = 200
}

variable "pd_data_disk_size" {
  type    = number
  default = 200
}

variable "pd_data_disk_throughput" {
  type    = number
  default = 200
}

variable "ticdc_data_disk_size" {
  type    = number
  default = 200
}

variable "ticdc_data_disk_throughput" {
  type    = number
  default = 200
}

## servers count

variable "tidb_count" {
	type = number
	description = "The numble of the tidb instances to be deployed"
	default = 2
}

variable "tikv_count" {
	type = number
	description = "The numble of the tikv instances to be deployed"
	default = 3
}

variable "pd_count" {
	type = number
	description = "The numble of the pd instances to be deployed"
	default = 3
}

variable "ticdc_count" {
  type = number
  description = "The numble of the ticdc worker instances to be deployed"
  default = 2
}

## tags 

variable "tags" {
    type = map(string)
    default = {
        "Owner" = "tf-azure-tidb",
        "Project" = "Azure TiDB Cluster",
        "Environment" = "test",
    }
    description = "The tags to be added to the resources"
}

## bastion allow ssh from
variable "bastion_allow_ssh_from" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
}