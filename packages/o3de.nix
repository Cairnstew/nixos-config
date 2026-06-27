{ lib, callPackage, ... }:
let
  # Re-export from the subdirectory so both flake outputs and overlay work.
  # The subdirectory needs pkgs-stable; the overlay provides it.
  # Auto-wired flake builds fall back to pkgs.python3 (see default.nix).
  pkg = callPackage ./o3de/default.nix { };
in pkg
