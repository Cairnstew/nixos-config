{ lib, config, ... }:
let
  cfg = config.my.system.battery;
in
{
  config = lib.mkIf cfg.enable {
    # Disable conflicting services
    services.tlp.enable = false;
    services.power-profiles-daemon.enable = false;

    # Thermal management
    services.thermald.enable = true;

    # CPU frequency scaling
    services.auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };

    # Lid behaviour (HandleLidSwitch* are the non-deprecated option paths)
    services.logind.settings.Login = {
      HandleLidSwitch = cfg.lidSwitch;
      HandleLidSwitchExternalPower = cfg.lidSwitchExternalPower;
      HandleLidSwitchDocked = cfg.lidSwitchDocked;
      LidSwitchIgnoreInhibited = "no";
    };
  };
}
