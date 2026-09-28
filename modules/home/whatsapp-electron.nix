{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.whatsapp-electron;
in
{
  options.my.programs.whatsapp-electron = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable WhatsApp Electron client.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.whatsapp-electron;
      defaultText = "pkgs.whatsapp-electron";
      description = "The whatsapp-electron package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ];

    # Desktop entry so wofi can find it
    xdg.desktopEntries.whatsapp-electron = {
      name = "WhatsApp";
      comment = "WhatsApp Desktop";
      exec = "${lib.getExe cfg.package}";
      categories = [ "InstantMessaging" "Network" ];
      icon = "whatsapp";
    };
  };
}
