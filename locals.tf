# Define Local Values in Terraform
locals {
  bastion_subnet = {
    name = "${var.name_prefix}-bastion"
    cidr = var.bastion_subnet_cidr
  }
  app_subnet = {
    name = "${var.name_prefix}-app"
    cidr = var.app_subnet_cidr
  }
  database_subnet = {
    name = "${var.name_prefix}-database"
    cidr = var.database_subnet_cidr
  }
}