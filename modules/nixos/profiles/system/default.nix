# modules/nixos/profiles/system/default.nix
# System-level profiles that can be enabled per-host
{ lib, config, flake, ... }:
let
  cfg = config.my.profiles;
  inherit (flake.config.me) username;
in
{
  imports = [
    ./development.nix
    ./gaming.nix
    ./workstation.nix
    ./server.nix
    ./minimal.nix
  ];

  # System profiles provide convenient bundles of related services/programs
  options.my.profiles = {
    # ── Role Profiles ──────────────────────────────────────────────────────
    workstation.enable = lib.mkEnableOption "workstation profile (desktop/laptop)";
    server.enable = lib.mkEnableOption "server profile (headless)";
    minimal.enable = lib.mkEnableOption "minimal profile (bare essentials)";
    gaming.enable = lib.mkEnableOption "gaming profile (steam, games, etc.)";
    development.enable = lib.mkEnableOption "development profile (dev tools, containers)";

    # ── Feature Profiles ─────────────────────────────────────────────────
    desktop.gnome.enable = lib.mkEnableOption "GNOME desktop environment";
    desktop.plasma.enable = lib.mkEnableOption "KDE Plasma desktop environment";
    
    gpu.mesa.enable = lib.mkEnableOption "Mesa GPU drivers (Intel/AMD)";
    gpu.nvidia.enable = lib.mkEnableOption "NVIDIA GPU drivers";
    gpu.nvidia-headless.enable = lib.mkEnableOption "NVIDIA GPU drivers (headless/CUDA)";
    
    location.enable = lib.mkEnableOption "location services (timezone, geoclue)";
    battery.enable = lib.mkEnableOption "battery/power management";
  };

  # Connect profiles to actual modules and assertions
  config = lib.mkMerge [
    # GNOME desktop profile
    (lib.mkIf cfg.desktop.gnome.enable {
      my.desktop.gnome.enable = true;
    })

    # Plasma desktop profile
    (lib.mkIf cfg.desktop.plasma.enable {
      my.services.plasmaX11.enable = true;
    })

    # Assertions to prevent conflicting profiles
    {
      assertions = [
        {
          assertion = !(cfg.gpu.mesa.enable && cfg.gpu.nvidia.enable);
          message = "Cannot enable both Mesa and NVIDIA GPU profiles.";
        }
        {
          assertion = !(cfg.desktop.gnome.enable && cfg.desktop.plasma.enable);
          message = "Cannot enable both GNOME and Plasma desktop profiles.";
        }
      ];
    }
  ];
}
