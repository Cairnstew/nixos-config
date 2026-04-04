locals {
  hosts     = jsondecode(var.cloud_hosts)
  aws_hosts = { for k, v in local.hosts : k => v if v.provider == "aws" }
}

provider "aws" {
  region = "eu-west-1"
}

module "aws" {
  for_each = local.aws_hosts

  source         = "./modules/aws"
  name           = each.key
  instance_type  = each.value.instance_type
  nixos_release  = each.value.nixos_release
  region         = each.value.region
  ssh_public_key = var.ssh_public_keys_aws

  providers = {
    aws = aws
  }
}