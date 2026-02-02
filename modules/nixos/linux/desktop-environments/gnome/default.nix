{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  
in
{
    imports = [
        ./gnome.nix
    ];
}

