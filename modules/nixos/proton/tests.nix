{ config, lib, ... }:
let
  cfg = config.my.programs.proton;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.programs.steam.enable or false;
      message = ''
        my.programs.proton.enable requires programs.steam to be enabled.
        Enable it via my.programs.steam.enable = true.
      '';
    }
  ];
}
