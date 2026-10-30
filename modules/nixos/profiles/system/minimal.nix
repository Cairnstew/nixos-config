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
    # Duplicate of common.nix my.services.tailscale.enable (same mkDefault) — removed (G12)
    # Duplicate of common.nix my.services.ssh.enable (same mkDefault) — removed (G12)

    # Note: This profile intentionally does NOT disable other services.
    # To create a truly minimal system, create a configuration that doesn't
    # import common.nix or selectively disables features.
  };
}
