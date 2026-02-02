{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
 imports = [
  ./bluetooth.nix
  ./audio.nix
  ./battery.nix
 ];
}
