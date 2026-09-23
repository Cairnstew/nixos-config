{ config, lib, ... }:

let
  cfg = config.my.programs.satisfactory;
in
{
  assertions = [
    {
      assertion = !(cfg.dedicatedServer.enable && !cfg.enable);
      message = "my.programs.satisfactory.dedicatedServer.enable requires my.programs.satisfactory.enable";
    }
  ];
}
