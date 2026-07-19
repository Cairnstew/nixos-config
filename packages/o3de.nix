{ lib, callPackage, pkgs, inputs, ... }:
let
  # The overlay (overlays/default.nix) passes pkgs-stable to o3de.
  # For the auto-wired flake output, import it here so default.nix gets
  # Python 3.10 from nixpkgs-stable regardless of which path builds o3de.
  pkgs-stable = import inputs.nixpkgs-stable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
  pkg = callPackage ./o3de/default.nix { inherit pkgs-stable; };
in
pkg
