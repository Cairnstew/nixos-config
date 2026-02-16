{ config, pkgs, lib, ... }:

let
  cfg = config.my.programs.discord;
in
{
  ######################
  # Options Definition #
  ######################
  options.my.programs.discord = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Discord for this user.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically start Discord on login.";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "Discord version to install (overrides nixpkgs version if needed).";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Extra packages or plugins to include with Discord.";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "dark";
      description = "Discord theme (if you have a theme loader installed).";
    };
  };

  ######################
  # Config Application #
  ######################
  config = lib.mkIf cfg.enable {

    # Install Discord and extra packages
    home.packages = [ (pkgs.discord.override { version = cfg.version; }) ] ++ cfg.extraPackages;

    # Environment variables for Discord (e.g., theme)
    home.sessionVariables = {
      DISCORD_THEME = cfg.theme;
    };

    # Autostart Discord
    home.file = lib.mkIf cfg.autostart {
    ".config/autostart/discord.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Discord
      Exec=${pkgs.discord}/bin/Discord
      X-GNOME-Autostart-enabled=true
      NoDisplay=false
      Comment=Start Discord on login
    '';
  };
  };
}
