{ config, flake, pkgs, lib,  ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
  homeMod = self + /modules/home;
in
{

  nixos-unified.sshTarget = "seanc@laptop";

  imports = [
    self.nixosModules.default
    ./configuration.nix
    (self + /modules/nixos/linux/zerotier.nix)
    (self + /modules/nixos/linux/freecad.nix)
    (self + /modules/nixos/linux/localsend.nix)
    (self + /modules/nixos/linux/freecad.nix)
    (self + /modules/nixos/linux/spotify.nix)
    (self + /modules/nixos/linux/steam.nix)
    (self + /modules/nixos/linux/obsidian.nix)
    (self + /modules/nixos/linux/rstudio.nix)



  ];

  home-manager.sharedModules = [
      
    ];
  services.openssh.enable = true;

}
