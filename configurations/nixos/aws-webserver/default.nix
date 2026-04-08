{ config, flake, lib, ... }:

let
  self = flake.inputs.self;
in
{
  imports = [
    self.nixosModules.cloud-vm
  ];

  nixpkgs.hostPlatform = "x86_64-linux";  # ← explicit, don't rely on module

  cloud-vm = {
    enable       = true;
    provider     = "aws";
    profile      = "web";
    instanceType = "t3.small";
    nixosRelease = "25.11";
    region       = "eu-west-1";
    secretsPath  = "/run/agenix/aws-cloud";
    diskDevice   = "/dev/nvme0n1";
  };

  cloud.aws.hosts = {
    my-server = {
      instance_type  = "t3.micro";
      region         = "eu-west-1";
      nixos_release  = "25.11";
      ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@host";
    };
  };

  services.openssh.settings.PermitRootLogin = "prohibit-password";

  networking.hostName = "aws-webserver";
}