	# Configuration common to all Linux systems
{ flake, lib, ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    # Common
    self.nixosModules.primary-as-admin
    self.nixosModules.caches
    self.nixosModules.ssh
    self.nixosModules.nix

    # Home Manager
    self.nixosModules.homeManager

    # Linux Specific
    self.nixosModules._1password
    self.nixosModules.audio
    self.nixosModules.battery
    self.nixosModules.bluetooth
    self.nixosModules.current-location


    inputs.agenix.nixosModules.default # Used in github-runner.nix & hedgedoc.nix

  ];

  boot.loader.grub.configurationLimit = 5; # Who needs more?
}
