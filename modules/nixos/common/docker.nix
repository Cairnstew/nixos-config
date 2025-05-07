{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{

  imports = [
      self.homeModules.default
    ];
  virtualisation.docker.enable = true;

  users.users.seanc.extraGroups = [ "docker" ];

  hardware.nvidia-container-toolkit.enable = true;
  
}