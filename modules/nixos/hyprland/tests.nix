{ config, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.programs.hyprland.enable;
      message = "Hyprland requires programs.hyprland.enable to be set.";
    }
  ];
}
