{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  # Enable root/global packages
  environment.systemPackages = with pkgs; [
    # List of global packages
    micro
    git
    gh
    # Add any other global packages here
  ];
}
