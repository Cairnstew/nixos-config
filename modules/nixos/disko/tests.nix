{ config, lib, ... }:
let
  cfg = config.my.disko.dualBoot;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.disk != "";
      message = "my.disko.dualBoot.disk must not be empty when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.windowsSizeGB > 0;
      message = "my.disko.dualBoot.windowsSizeGB must be positive when enabled.";
    }
    {
      assertion = !cfg.enable || cfg.espSizeGB > 0;
      message = "my.disko.dualBoot.espSizeGB must be positive when enabled.";
    }
  ];
}
