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
      assertion = !cfg.enable || cfg.settings.server.authMode == "none"
                  || (cfg.settings.server.authUsername != null && cfg.settings.server.authPasswordFile != null);
      message = "my.services.suwayomi.settings.server: authUsername and authPasswordFile must be set when authMode is not 'none'.";
    }
  ];
}
