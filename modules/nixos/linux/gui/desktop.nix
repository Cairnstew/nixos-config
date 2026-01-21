{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.desktop-config.nixosModules.Plasma6
  ];

}
