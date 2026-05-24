{ config, lib, ... }:
let
  cfg = config.my.services.windowsInstaller;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.windowsDisk != "";
      message = "my.services.windowsInstaller.windowsDisk must be set when enabled.";
    }
  ];
}
