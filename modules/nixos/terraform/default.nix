{ flake, pkgs, lib, ... }:
{
  terraform = {
    required_providers.aws = {
      source  = "hashicorp/aws";
      version = "~> 5.0";
    };
    # Local state is fine for solo use; swap for S3 backend in teams
    # backend.s3 = { bucket = "my-tfstate"; key = "infra.tfstate"; region = "eu-west-1"; };
  };

  provider.aws.region = "eu-west-1";

  # Pull the official NixOS AMI via terraform-nixos
  # Pin the ref to a specific commit for reproducibility
  module.nixos_image = {
    source  = "github.com/nix-community/terraform-nixos//aws_image_nixos?ref=5dc93b9a39f31a7963bb13de5f7e7ec030024e8e";
    region  = "eu-west-1";
    release = "24.11";
  };

  resource.aws_instance.web = {
    ami           = "\${module.nixos_image.ami}";
    instance_type = "t3.micro";
    key_name      = "my-ssh-key";   # must already exist in AWS
    tags.Name     = "web";
  };

  # Push your NixOS config to the machine once it's up
  module.deploy_web = {
    source          = "github.com/nix-community/terraform-nixos//deploy_nixos?ref=5dc93b9a39f31a7963bb13de5f7e7ec030024e8e";
    nixos_config    = toString ../nixos/web.nix;
    target_host     = "\${aws_instance.web.public_ip}";
    ssh_private_key = "\${file(pathexpand(\"~/.ssh/id_ed25519\"))}";
  };
}