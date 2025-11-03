{ config, flake, pkgs, lib,  ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixosModules.default
    self.nixosModules.server
    ./configuration.nix
    #(self + /modules/nixos/shared/github-runner.nix)
  ];
  services.openssh.enable = true;
  nixos-unified.sshTarget = "seanc@laptop";

}
