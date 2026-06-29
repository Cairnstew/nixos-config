{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.tailscaleWatchdog;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.alertCooldown > 0;
      message = "tailscaleWatchdog.alertCooldown must be positive when enabled.";
    }
    {
      assertion = !cfg.enable || config.my.services.emailAlerts.enable;
      message = "tailscaleWatchdog requires my.services.emailAlerts.enable = true.";
    }
  ];
}
