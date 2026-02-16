{ lib, config, pkgs, ... }:

let
  cfg = config.my.system.battery;
in
{
  options.my.system.battery = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable auto-cpufreq with thermald and disable conflicting power managers";
    };
  };

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
  };
}
