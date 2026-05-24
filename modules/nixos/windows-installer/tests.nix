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
    {
      assertion = !cfg.enable || cfg.windowsPartitionIndex >= 1;
      message = "my.services.windowsInstaller.windowsPartitionIndex must be >= 1.";
    }
    {
      assertion = !cfg.enable || cfg.dscConfigPath == null || cfg.dscConfigPath != "";
      message = "my.services.windowsInstaller.dscConfigPath must not be empty when set.";
    }
  ];
}
