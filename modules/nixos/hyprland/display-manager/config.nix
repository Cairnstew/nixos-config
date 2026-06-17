{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  dmCfg = cfg.displayManager;
in
{
  config = lib.mkIf (cfg.enable && dmCfg.enable) {
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${dmCfg.greeter}/bin/tuigreet --time --remember --cmd ${dmCfg.sessionCommand}";
        user = "greeter";
      };
    };
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };
  };
}
