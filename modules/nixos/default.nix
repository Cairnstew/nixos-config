	# Configuration common to all Linux systems
{ flake, lib, ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    {
      users.users.${config.me.username}.isNormalUser = lib.mkDefault true;
      home-manager.users.${config.me.username} = { };
      home-manager.backupFileExtension = "backup";
      home-manager.sharedModules = [
        self.homeModules.default
        self.homeModules.linux-only
      ];
    }
    self.nixosModules.common
    inputs.agenix.nixosModules.default # Used in github-runner.nix & hedgedoc.nix
    ./linux/current-location.nix
    ./linux/core
    ./linux/gui/gnome
  ];

  boot.loader.grub.configurationLimit = 5; # Who needs more?
}
