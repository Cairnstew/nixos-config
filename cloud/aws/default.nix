# cloud/aws/default.nix — Amazon Web Services infrastructure (terranix module)
#
# Terranix module (not a NixOS module) evaluated into `config.tf.json` and
# driven by OpenTofu via the terranix flakeModule:
#
#   nix run .#aws -- plan
#   nix run .#aws -- apply
#   nix run .#aws -- destroy
#
# Two-stage pattern: this provisions the VPC + EC2 host, then the NixOS
# configuration is pushed with `nixos-anywhere` / `colmena`
# (see cloud/README.md).
{ lib, ... }:
{
  terraform.required_providers.aws = {
    source = "hashicorp/aws";
    version = "~> 5.0";
  };

  provider.aws = {
    region = lib.tf.ref "var.region";
  };

  variable.region = {
    description = "AWS region";
    type = "string";
    default = "eu-west-2";
  };
}
