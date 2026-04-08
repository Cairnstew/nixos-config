{ lib, ... }: {
  imports = [
    ./aws.nix
    ./google.nix  # ← must be terranix/google.nix, not modules/nixos/cloud-vm/google.nix
  ];
}