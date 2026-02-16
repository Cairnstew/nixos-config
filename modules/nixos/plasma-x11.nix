{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.plasmaX11;
in
{
  options.my.services.plasmaX11 = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable X11 with SDDM and Plasma 5 desktop";
    };

    hidpi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable HiDPI support";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      displayManager.sddm.enable = true;
      desktopManager.plasma5.enable = true;
    };

    hardware.video.hidpi.enable = lib.mkDefault cfg.hidpi;

    environment.systemPackages = with pkgs; [
      # plasma-addons, etc if you want later
    ];
  };
}
