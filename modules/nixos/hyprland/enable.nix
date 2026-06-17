{ config, lib, ... }:
let
  inherit (lib) mkIf mkDefault;
  cfg = config.my.desktop.hyprland;
in
{
  config = mkIf cfg.enable {
    my.desktop.hyprland = {
      core.enable            = mkDefault true;
      bar.enable             = mkDefault true;
      launcher.enable        = mkDefault true;
      notifications.enable   = mkDefault true;
      wallpapers.enable      = mkDefault true;
      lockscreen.enable      = mkDefault true;
      screenshot.enable      = mkDefault true;
      clipboard.enable       = mkDefault true;
      portal.enable          = mkDefault true;
      displayManager.enable  = mkDefault true;
      audio.enable           = mkDefault true;
      utilities.enable       = mkDefault true;
      nvidia.enable          = mkDefault false;
      awww.enable            = mkDefault false;
    };
  };
}
