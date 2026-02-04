# Configuration common to all Linux systems
{ flake, lib, ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixosModules.default
    self.nixosModules.zerotier
    self.nixosModules.zeronsd

  ];

  boot.loader.grub.configurationLimit = 5; # Who needs more?
}