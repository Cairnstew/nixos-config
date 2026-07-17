{ config, lib, ... }:
let
  cfg = config.my.services.radarr;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.radarr.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.radarr.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.radarr.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.radarr.group must not be empty.";
    }
  ];
}
