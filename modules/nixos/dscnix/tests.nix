{ config, lib, flake, ... }:
let
  cfg = config.my.services.dscnix;
in
{
  assertions = [
    {
      assertion = !cfg.enable || (cfg.configurationName != "");
      message = "my.services.dscnix.configurationName must not be empty when dscnix is enabled.";
    }
  ];


}
