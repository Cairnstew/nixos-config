{ config, lib, ... }:
let
  cfg = config.my.programs._1password;
in
{
  assertions = [
    {
      assertion = !cfg.gui.enable || cfg.enable;
      message = "my.programs._1password.gui.enable requires my.programs._1password.enable.";
    }
    {
      assertion = !cfg.gui.enable || config.security.polkit.enable;
      message = "The 1Password desktop app requires polkit to be enabled.";
    }
  ];
}
