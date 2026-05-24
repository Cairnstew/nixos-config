{ config, lib, ... }:
let
  cfg = config.my.services.sillytavern;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.port > 0;
      message = "my.services.sillytavern.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.sillytavern.user must not be empty.";
    }
  ];
}
