{ config, lib, ... }:
let
  cfg = config.my.services.sonarr;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.sonarr.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.sonarr.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.sonarr.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.sonarr.group must not be empty.";
    }
  ];
}
