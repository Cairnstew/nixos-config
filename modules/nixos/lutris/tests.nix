{ config, lib, ... }:
let
  cfg = config.my.programs.lutris;
  bnet = cfg.battlenet;
in
{
  assertions = [
    {
      assertion = !cfg.enable -> !cfg.gamescope.openFirewall;
      message = "my.programs.lutris.gamescope.openFirewall requires my.programs.lutris.enable = true.";
    }
    {
      assertion = !bnet.enable || cfg.enable;
      message = "my.programs.lutris.battlenet.enable requires my.programs.lutris.enable = true.";
    }
    {
      assertion = !bnet.enable || bnet.settings.esync || bnet.settings.fsync;
      message = "my.programs.lutris.battlenet: at least one of esync or fsync should be enabled for acceptable performance.";
    }
  ];
}
