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
    my.programs.proton.enable = lib.mkDefault true;

    # ── Mouse Acceleration via maccel kernel module ────────────────────────
    # Kernel-level mouse acceleration that works on GNOME Wayland by
    # intercepting evdev events before mutter sees them. GNOME's mousemeter
    # will show no acceleration (because maccel handles it in the kernel),
    # but the cursor movement will have the configured curve applied.
    # ── Endcord TUI Discord (disabled) ──────────────────────────────────────
    home-manager.users.${username}.my.programs.discord.tui = {
      enable = lib.mkDefault false;
    };

    my.hardware.mouse = {
      enable = true;

      parameters = {
        mode = "linear";
        sensMultiplier = 1.0;
        acceleration = 0.3;
        offset = 4.0;
        outputCap = 3.0;
      };
    };
  };
}
