{ config, lib, ... }:
let
  cfg = config.my.services.jan;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.jan.dataDir must not be empty.";
    }
    {
      assertion = !cfg.apiServer.enable || cfg.apiServer.port > 0;
      message = "my.services.jan.apiServer.port must be a valid port number.";
    }
  ];
}
