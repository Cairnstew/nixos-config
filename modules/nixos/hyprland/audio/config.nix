{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  audioCfg = cfg.audio;
in
{
  config = lib.mkIf (cfg.enable && audioCfg.enable) {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
    };
    security.rtkit.enable = true;
  };
}
