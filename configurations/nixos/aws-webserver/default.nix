{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  imports = [ self.nixosModules.cloud-vm ];

  my.cloud-vm = {
    enable       = true;        # ← this triggers nixpkgs.hostPlatform = "x86_64-linux"
    provider     = "aws";
    profile      = "web";
    instanceType = "t3.micro";
    nixosRelease = "24.11";
    region       = "eu-west-1";
    secretsPath  = "/run/agenix/aws-labs";
  };

  networking.hostName = "aws-webserver";
}