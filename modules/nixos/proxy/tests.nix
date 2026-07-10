{ config, lib, ... }:
let
  cfg = config.my.services.proxy;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.proxy.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.listenAddresses != [ ];
      message = "my.services.proxy.listenAddresses must not be empty.";
    }
  ];
}
