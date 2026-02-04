{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
    services.udisks2.enable = true;

    #home-manager.sharedModules = [
    #  "${homeMod}/all/utils/udiskie.nix"
    #];
}
