{ config, lib, ... }:
let
  cfg = config.my.programs._1password;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.security.polkit.enable;
      message = "1Password requires polkit to be enabled.";
    }
  ];
}
