# Configuration common to all Linux systems
{ flake, lib, ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixosModules.common
    inputs.agenix.nixosModules.default # Used in github-runner.nix & hedgedoc.nix
    ./linux/current-location.nix
    ./linux/zerotier.nix
    ./linux/zeronsd.nix
    ./linux/zerotier.nix


  ];

  boot.loader.grub.configurationLimit = 5; # Who needs more?
}