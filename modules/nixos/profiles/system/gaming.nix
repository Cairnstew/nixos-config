# modules/nixos/profiles/system/gaming.nix
# Gaming profile with Steam, gaming tools, and mouse acceleration
{ config, lib, flake, ... }:
let
  cfg = config.my.profiles.gaming;
  inherit (flake.config.me) username;
in
{
  config = lib.mkIf cfg.enable {
    # ── Gaming dependencies ────────────────────────────────────────────────
    my.system.audio.enable = lib.mkDefault true;
    my.programs.steam.enable = lib.mkDefault true;
    my.programs.hearthstone.enable = lib.mkDefault true;
    my.programs.proton.enable = lib.mkDefault true;

    # ── Home-manager program defaults for the gaming profile ────────────────
    home-manager.users.${username}.my.programs = {
      minecraft.enable = lib.mkDefault true;
      discord.tui = {
        enable = lib.mkDefault false;
      };
    };

    # ── Mouse Acceleration via maccel kernel module ────────────────────────
    # Kernel-level mouse acceleration that works on GNOME Wayland by
    # intercepting evdev events before mutter sees them. GNOME's mousemeter
    # will show no acceleration (because maccel handles it in the kernel),
    # but the cursor movement will have the configured curve applied.
    my.hardware.mouse.enable = lib.mkDefault true;
  };
}
