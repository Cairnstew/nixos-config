{ config, lib, ... }:
let
  cfg = config.my.homeManager;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.extraModules == [ ] || (builtins.isList cfg.extraModules);
      message = "my.homeManager.extraModules must be a list.";
    }
  ];
}
