{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.discord;
in
{
  config = lib.mkIf cfg.enable {

    home.packages = [ cfg.package ] ++ cfg.extraPackages;

    home.sessionVariables = {
      DISCORD_THEME = cfg.theme;
    };

    home.file = lib.mkIf cfg.autostart {
      ".config/autostart/discord.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Discord
        Exec=${cfg.package}/bin/Discord
        X-GNOME-Autostart-enabled=true
        NoDisplay=false
        Comment=Start Discord on login
      '';
    };
  };
}
