# flake-parts module template following nixos-unified conventions
{ lib, ... }:
{
  # Use 'perSystem' for platform-specific outputs (packages, apps, checks, devShells)
  perSystem = { config, self', inputs', pkgs, system, ... }: {
    # Example package
    # packages.my-package = pkgs.callPackage ./package.nix { };

    # Example devShell
    # devShells.default = pkgs.mkShell {
    #   packages = with pkgs; [ ];
    # };
  };

  # Use top-level 'flake' for platform-agnostic exports
  # flake = {
  #   nixosModules.my-module = import ../nixos/my-module;
  # };
}
