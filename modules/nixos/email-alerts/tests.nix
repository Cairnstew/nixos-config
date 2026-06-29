{ config, lib, ... }:
let
  cfg = config.my.services.emailAlerts;
in
{
  assertions = [
    {
      assertion = !cfg.enable || (lib.length cfg.to) > 0;
      message = "my.services.emailAlerts: at least one recipient required in 'to' list when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.smtp.port > 0;
      message = "my.services.emailAlerts: smtp.port must be positive.";
    }
  ];
}
