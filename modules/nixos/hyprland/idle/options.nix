{ lib, ... }:
{
  options.my.desktop.hyprland.idle = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hypridle idle daemon for auto-lock and suspend on inactivity.";
    };
    lockTimeout = lib.mkOption {
      type = lib.types.int;
      default = 300;
      example = 600;
      description = "Seconds of inactivity before locking the screen (0 to disable).";
    };
    dpmsTimeout = lib.mkOption {
      type = lib.types.int;
      default = 600;
      example = 900;
      description = "Seconds of inactivity before turning off displays via DPMS (0 to disable).";
    };
    suspendTimeout = lib.mkOption {
      type = lib.types.int;
      default = 900;
      example = 1800;
      description = "Seconds of inactivity before suspending the system (0 to disable).";
    };
  };
}
