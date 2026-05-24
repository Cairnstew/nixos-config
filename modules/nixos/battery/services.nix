{ lib, config, ... }:
let
  cfg = config.my.system.battery;
in
{
  config = lib.mkIf cfg.enable {
    # Optionally nuke suspend entirely for remote access machines
    systemd.services.systemd-suspend.enable = lib.mkIf cfg.disableSuspend false;
    systemd.targets.suspend.enable = lib.mkIf cfg.disableSuspend false;
    systemd.targets.sleep.enable = lib.mkIf cfg.disableSuspend false;
    systemd.targets.hibernate.enable = lib.mkIf cfg.disableSuspend false;
    systemd.targets.hybrid-sleep.enable = lib.mkIf cfg.disableSuspend false;
  };
}
