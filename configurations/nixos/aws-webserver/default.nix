{ config, flake, lib, ... }:

let
  self = flake.inputs.self;
in
{
  imports = [
    self.nixosModules.cloud-vm
  ];

  my.cloud-vm = {
    enable       = true;
    provider     = "aws";
    profile      = "web";
    instanceType = "t3.small";
    nixosRelease = "25.11";
    region       = "eu-west-1";
    diskDevice   = "/dev/nvme0n1";  
  };

  services.openssh = {
    enable                          = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin        = lib.mkDefault "prohibit-password";
  };

  networking.hostName = "aws-webserver";
}