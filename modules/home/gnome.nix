{ config, pkgs, lib, ... }:
let
  cfg = config.my.desktop.gnome;
in
{
  options.my.desktop.gnome = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GNOME desktop customizations";
    };

    favoriteApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "firefox.desktop"
        "code.desktop"
        "org.gnome.Terminal.desktop"
        "spotify.desktop"
      ];
      description = "List of favorite applications in GNOME dash";
    };

    workspaceNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "Main" ];
      description = "Names for GNOME workspaces";
    };

    enableHotCorners = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GNOME hot corners";
    };

    backgroundImage = lib.mkOption {
      type = lib.types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-l.png";
      description = "Path to background image (light mode)";
    };

    backgroundImageDark = lib.mkOption {
      type = lib.types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
      description = "Path to background image (dark mode)";
    };

    screensaverImage = lib.mkOption {
      type = lib.types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
      description = "Path to screensaver image";
    };

    suspendTimeoutAC = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Suspend timeout when on AC power (0 = disabled, seconds otherwise)";
    };

    suspendTimeoutBattery = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Suspend timeout when on battery (seconds, 300 = 5 minutes)";
    };

    gtkTheme = lib.mkOption {
      type = lib.types.str;
      default = "Breeze-Dark";
      description = "GTK theme name";
    };

    iconTheme = lib.mkOption {
      type = lib.types.str;
      default = "Papirus-Dark";
      description = "Icon theme name";
    };
  };

  config = lib.mkIf cfg.enable {
    dconf = {
      settings = {
        "org/gnome/shell" = {
          favorite-apps = cfg.favoriteApps;
        };
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          enable-hot-corners = cfg.enableHotCorners;
          can-change-accels = true;
        };
        "org/gnome/desktop/wm/preferences" = {
          workspace-names = cfg.workspaceNames;
        };
        "org/gnome/desktop/background" = {
          picture-uri = cfg.backgroundImage;
          picture-uri-dark = cfg.backgroundImageDark;
        };
        "org/gnome/desktop/screensaver" = {
          picture-uri = cfg.screensaverImage;
          primary-color = "#3465a4";
          secondary-color = "#000000";
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-timeout = cfg.suspendTimeoutAC;
          sleep-inactive-battery-timeout = cfg.suspendTimeoutBattery;
        };
      };
    };
    
    gtk = {
      enable = true;
      gtk3 = {
        extraConfig = {
          gtk-application-prefer-dark-theme = true;
        };
      };
      iconTheme = {
        name = cfg.iconTheme;
      };
      theme = {
        name = cfg.gtkTheme;
      };
    };
  };
}