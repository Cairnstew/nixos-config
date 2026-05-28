# Thin re-export: imports the self-contained NixOS module from the ipxe-installer package
{ lib, pkgs, config, ... }:

let
  # The package lives in packages/ipxe-installer/
  module = import ../../packages/ipxe-installer/modules/nixos.nix;
in {
  imports = [ module ];
}
