# modules/nixos/profiles/system/minimal.nix
# Minimal profile with bare essentials
# This profile only sets explicit enables, not disables
{ config, lib, ... }:
let
  cfg = config.my.profiles.minimal;
in
{
  config = lib.mkIf cfg.enable {
    # ── Core only ──────────────────────────────────────────────────────────
    # mkDefault true: Even minimal systems need remote access
    # Override when: Truly isolated system with physical access only
    my.services.tailscale.enable = lib.mkDefault true;
    my.services.ssh.enable = lib.mkDefault true;

    # Note: This profile intentionally does NOT disable other services.
    # To create a truly minimal system, create a configuration that doesn't
    # import common.nix or selectively disables features.
  };
}
