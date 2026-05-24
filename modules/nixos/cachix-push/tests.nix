{ config, lib, ... }:
let
  cfg = config.my.services.cachix-push;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.cacheName != "";
      message = "my.services.cachix-push.cacheName must be set when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.tokenFile != "";
      message = "my.services.cachix-push.tokenFile must be set when enabled.";
    }
  ];
}
