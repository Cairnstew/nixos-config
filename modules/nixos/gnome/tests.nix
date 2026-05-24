{ config, lib, ... }:
let
  cfg = config.my.desktop.gnome;
in
{
  assertions = [
    {
      assertion = !cfg.enable || config.services.desktopManager.gnome.enable;
      message = "GNOME desktop requires services.desktopManager.gnome.enable to be set.";
    }
  ];
}
