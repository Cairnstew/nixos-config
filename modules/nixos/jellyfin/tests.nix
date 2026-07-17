{ config, lib, ... }:
let
  cfg = config.my.services.jellyfin;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.dataDir != "";
      message = "my.services.jellyfin.dataDir must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.services.jellyfin.user must not be empty.";
    }
    {
      assertion = !cfg.enable || cfg.group != "";
      message = "my.services.jellyfin.group must not be empty.";
    }
  ];
}
