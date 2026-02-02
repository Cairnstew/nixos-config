{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  
in
{
    imports = [
      ./_1password.nix
    ];
}

