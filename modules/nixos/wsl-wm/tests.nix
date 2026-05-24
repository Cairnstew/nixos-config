{ config, lib, ... }:
let
  cfg = config.my.services.wsl-wm;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.windowManager != "";
      message = "my.services.wsl-wm.windowManager must not be empty when enabled.";
    }
  ];
}
