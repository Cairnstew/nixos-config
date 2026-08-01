{ config, ... }:
let
  cfg = config.my.services.ttyd;
in
{
  assertions = [
    {
      assertion = !cfg.enable || (cfg.username != null) == (cfg.passwordFile != null);
      message = "my.services.ttyd requires both username and passwordFile to be set (or neither).";
    }
    {
      assertion = !cfg.enable || (cfg.username != null && cfg.passwordFile != null);
      message = ''
        my.services.ttyd must have HTTP basic auth (username + passwordFile)
        configured. Use an agenix secret path for passwordFile.
      '';
    }
    {
      assertion = !cfg.enable || cfg.port >= 1024 || cfg.user == null;
      message = "my.services.ttyd.port must be >= 1024 when running as root.";
    }
  ];
}
