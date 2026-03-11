{ lib, config, pkgs, ... }:
let
  cfg = config.my.system.battery;
in
{
  options.my.system.battery = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Enable auto-cpufreq with thermald and disable conflicting power managers";
    };

    lidSwitch = lib.mkOption {
      type    = lib.types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
      default = "suspend";
      description = "What to do when the lid is closed on battery";
    };

    lidSwitchExternalPower = lib.mkOption {
      type    = lib.types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
      default = "ignore";
      description = "What to do when the lid is closed on AC power";
    };

    lidSwitchDocked = lib.mkOption {
      type    = lib.types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
      default = "ignore";
      description = "What to do when the lid is closed while docked";
    };

    disableSuspend = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Completely disable suspend (useful for remote access via RustDesk etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Disable conflicting services
    services.tlp.enable                   = false;
    services.power-profiles-daemon.enable = false;

    # Thermal management
    services.thermald.enable = true;

    # CPU frequency scaling
    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo    = "never";
        };
        charger = {
          governor = "performance";
          turbo    = "auto";
        };
      };
    };

    # Lid behaviour
    services.logind = {
      lidSwitch              = cfg.lidSwitch;
      lidSwitchExternalPower = cfg.lidSwitchExternalPower;
      lidSwitchDocked        = cfg.lidSwitchDocked;
      settings.Login.LidSwitchIgnoreInhibited = "no";
    };

    # Optionally nuke suspend entirely for remote access machines
    systemd.services.systemd-suspend.enable  = lib.mkIf cfg.disableSuspend false;
    systemd.targets.suspend.enable           = lib.mkIf cfg.disableSuspend false;
    systemd.targets.sleep.enable             = lib.mkIf cfg.disableSuspend false;
    systemd.targets.hibernate.enable         = lib.mkIf cfg.disableSuspend false;
    systemd.targets.hybrid-sleep.enable      = lib.mkIf cfg.disableSuspend false;
  };
}