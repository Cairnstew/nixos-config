{ lib, ... }:
let
  inherit (lib) mkOption types mkEnableOption;
in
{
  options.my.system.battery = {
    enable = mkEnableOption "auto-cpufreq with thermald and disable conflicting power managers";

    lidSwitch = mkOption {
      type = types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
      default = "suspend";
      description = "What to do when the lid is closed on battery";
    };

    lidSwitchExternalPower = mkOption {
      type = types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
      default = "ignore";
      description = "What to do when the lid is closed on AC power";
    };

    lidSwitchDocked = mkOption {
      type = types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
      default = "ignore";
      description = "What to do when the lid is closed while docked";
    };

    disableSuspend = mkOption {
      type = types.bool;
      default = false;
      description = "Completely disable suspend (useful for remote access via RustDesk etc.)";
    };
  };
}
