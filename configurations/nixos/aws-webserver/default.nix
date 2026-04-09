{ config, flake, lib, ... }:

let
  self = flake.inputs.self;
in {
  imports = [
    
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  services.openssh.settings.PermitRootLogin = "prohibit-password";

  networking.hostName = "aws-webserver";
}