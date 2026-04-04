locals {
  hosts     = jsondecode(var.cloud_hosts)
  aws_hosts = { for k, v in local.hosts : k => v if v.provider == "aws" }
}

# One provider per unique region used by aws hosts
provider "aws" {
  region = "eu-west-1"  # or make dynamic if you have multiple regions
}

module "aws" {
  for_each = local.aws_hosts

  source        = "./modules/aws"
  name          = each.key
  instance_type = each.value.instance_type
  nixos_release = each.value.nixos_release
  region        = each.value.region

  providers = {
    aws = aws
  }
}