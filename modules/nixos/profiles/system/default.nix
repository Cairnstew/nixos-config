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

    gpu.mesa.enable = lib.mkEnableOption "Mesa GPU drivers (Intel/AMD)";
    gpu.nvidia.enable = lib.mkEnableOption "NVIDIA GPU drivers";
    gpu.nvidia-headless.enable = lib.mkEnableOption "NVIDIA GPU drivers (headless/CUDA)";

    location.enable = lib.mkEnableOption "location services (timezone, geoclue)";
    battery.enable = lib.mkEnableOption "battery/power management (auto-cpufreq, logind)";

    # ── Power Profiles (GNOME power settings) ─────────────────────────────
    power.desktop.enable = lib.mkEnableOption "desktop power profile (never sleep, no lock)";
    power.laptop.enable = lib.mkEnableOption "laptop power profile (battery-aware, lock on idle)";
  };

  # Connect profiles to actual modules and assertions
  config = lib.mkMerge [
    # GNOME desktop profile
    (lib.mkIf cfg.desktop.gnome.enable {
      my.desktop.gnome.enable = true;
    })

    # NVIDIA GPU profile (full desktop)
    (lib.mkIf cfg.gpu.nvidia.enable {
      my.hardware.gpu.nvidia.enable = true;
      my.hardware.gpu.nvidia.headless = false;
    })

    # NVIDIA GPU profile (headless/CUDA)
    (lib.mkIf cfg.gpu.nvidia-headless.enable {
      my.hardware.gpu.nvidia.enable = true;
      my.hardware.gpu.nvidia.headless = true;
    })

    # Mesa GPU profile
    (lib.mkIf cfg.gpu.mesa.enable {
      my.hardware.gpu.mesa.enable = true;
    })

    # Battery/power management profile
    (lib.mkIf cfg.battery.enable {
      my.system.battery.enable = true;
    })

    # ── Power: Desktop profile (always plugged in) ────────────────────────
    (lib.mkIf (cfg.desktop.gnome.enable && cfg.power.desktop.enable) {
      home-manager.users.${username}.my.desktop.gnome = {
        screenBlankTimeout = lib.mkDefault 900;
        sleepInactiveACTimeout = lib.mkDefault 7200;
        sleepInactiveACType = lib.mkDefault "nothing";
        sleepInactiveBatteryTimeout = lib.mkDefault 7200;
        sleepInactiveBatteryType = lib.mkDefault "nothing";
        powerButtonAction = lib.mkDefault "nothing";
        lockEnabled = lib.mkDefault false;
      };
    })

    # ── Power: Laptop profile (battery-aware) ──────────────────────────────
    (lib.mkIf (cfg.desktop.gnome.enable && cfg.power.laptop.enable) {
      home-manager.users.${username}.my.desktop.gnome = {
        screenBlankTimeout = lib.mkDefault 300;
        sleepInactiveACTimeout = lib.mkDefault 3600;
        sleepInactiveACType = lib.mkDefault "nothing";
        sleepInactiveBatteryTimeout = lib.mkDefault 1800;
        sleepInactiveBatteryType = lib.mkDefault "nothing";
        powerButtonAction = lib.mkDefault "nothing";
        idleBrightness = lib.mkDefault 20;
        lockEnabled = lib.mkDefault true;
        lockDelay = lib.mkDefault 0;
      };
      my.profiles.battery.enable = lib.mkDefault true;
    })

    # Assertions to prevent conflicting profiles
    {
      assertions = [
        {
          assertion = !(cfg.gpu.mesa.enable && cfg.gpu.nvidia.enable);
          message = "Cannot enable both Mesa and NVIDIA GPU profiles.";
        }
        {
          assertion = !(cfg.power.desktop.enable && cfg.power.laptop.enable);
          message = "Cannot enable both desktop and laptop power profiles.";
        }
        {
          assertion = (cfg.power.desktop.enable || cfg.power.laptop.enable) -> cfg.desktop.gnome.enable;
          message = "Power profiles require GNOME desktop profile (my.profiles.desktop.gnome.enable).";
        }
      ];
    }
  ];
}
