{ config, lib, ... }:
let
  cfg = config.my.services.prowlarr;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.prowlarr.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.prowlarr.port must be a valid port number.";
    }
  ];
}
