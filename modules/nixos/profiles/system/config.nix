{ lib, config, flake, ... }:
let
  cfg = config.my.profiles;
  inherit (flake.config.me) username;
in
{
  config = lib.mkMerge [
    # Desktop choice (convenience toggle — sets hyprland or gnome)
    (lib.mkIf (cfg.desktop.choice == "hyprland") {
      my.desktop.hyprland = {
        enable = true;
        idle = {
          enable = true;
          dpmsTimeout = 60;
          suspendTimeout = 0;
        };
        colorpicker.enable = true;
        nightLight.enable = true;
        pyprland.enable = true;
        pyprland.plugins = [ "scratchpads" "expose" "toggle_dpms" ];
        wallpapers = {
          backend = "awww";
          settings.awww = {
            transitionType = "simple";
            transitionStep = 2;
            transitionFps = 30;
          };
        };
      };
    })
    (lib.mkIf (cfg.desktop.choice == "gnome") {
      my.desktop.gnome.enable = true;
    })

    # Hyprland profile
    (lib.mkIf cfg.desktop.hyprland.enable {
      my.desktop.hyprland = {
        enable = true;
        idle = {
          enable = true;
          dpmsTimeout = 60;
          suspendTimeout = 0;
        };
        colorpicker.enable = true;
        nightLight.enable = true;
        pyprland.enable = true;
        pyprland.plugins = [ "scratchpads" "expose" "toggle_dpms" ];
        wallpapers = {
          backend = "awww";
          settings.awww = {
            transitionType = "simple";
            transitionStep = 2;
            transitionFps = 30;
          };
        };
      };
    })
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

    # Location profile (timezone, geoclue)
    (lib.mkIf cfg.location.enable {
      my.system.location.enable = true;
    })

    # Testing profile
    (lib.mkIf cfg.testing.enable {
      my.testing.enable = true;
    })

    # ── Theming: Stylix ─────────────────────────────────────────────────────
    (lib.mkIf cfg.theming.stylix.enable {
      my.theming.stylix.enable = true;
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
          message = "Power profiles require my.profiles.desktop.gnome.enable.";
        }
      ];
    }
  ];
}
