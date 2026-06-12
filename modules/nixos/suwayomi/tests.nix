{ config, lib, ... }:
let
  cfg = config.my.services.suwayomi;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.settings.server.port > 0;
      message = "my.services.suwayomi.settings.server.port must be a valid port number.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.suwayomi.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.suwayomi.group must not be empty.";
    }
    {
      assertion = !cfg.enable || !cfg.settings.server.basicAuthEnabled
                  || (cfg.settings.server.basicAuthUsername != null && cfg.settings.server.basicAuthPasswordFile != null);
      message = "my.services.suwayomi.settings.server: basicAuthUsername and basicAuthPasswordFile must be set when basicAuthEnabled is true.";
    }
  ];
}
