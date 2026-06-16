{ config, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.desktop.hyprland.user must be set when hyprland is enabled.";
    }
  ];
}
