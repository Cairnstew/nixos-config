module "nixos_image" {
  for_each = var.cloud_hosts
  source   = "git::https://github.com/nix-community/terraform-nixos.git//aws_image_nixos?ref=master"
  release  = each.value.nixos_release
}

resource "aws_instance" "hosts" {
  for_each        = var.cloud_hosts
  ami             = module.nixos_image[each.key].ami
  instance_type   = each.value.instance_type
  key_name        = aws_key_pair.deployer.key_name
  security_groups = [aws_security_group.nixos.name]

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = {
    Name = each.key
  }
}

module "deploy_nixos" {
  for_each = var.cloud_hosts
  source   = "git::https://github.com/nix-community/terraform-nixos.git//deploy_nixos?ref=master"

  nixos_config         = "${var.flake_root}#nixosConfigurations.${each.key}.config.system.build.toplevel"
  target_host          = aws_instance.hosts[each.key].public_ip
  target_user          = "root"
  ssh_private_key_file = local_sensitive_file.deployer_ssh_key.filename

  triggers = {
    instance_id = aws_instance.hosts[each.key].id
  }
}

output "hosts" {
  value = {
    for name, instance in aws_instance.hosts : name => {
      ip  = instance.public_ip
      ssh = "ssh -i ${local_sensitive_file.deployer_ssh_key.filename} root@${instance.public_ip}"
    }
  }
}