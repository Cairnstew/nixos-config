{ config, pkgs, lib, ... }:
let
  cfg = config.my.desktop.gnome;
in
{
  options.my.desktop.gnome = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Enable GNOME desktop customizations";
    };
    favoriteApps = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [
        "firefox.desktop"
        "code.desktop"
        "org.gnome.Terminal.desktop"
        "spotify.desktop"
      ];
      description = "List of favorite applications in GNOME dash";
    };
    workspaceNames = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [ "Main" ];
      description = "Names for GNOME workspaces";
    };
    enableHotCorners = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Enable GNOME hot corners";
    };
    backgroundImage = lib.mkOption {
      type    = lib.types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-l.png";
      description = "Path to background image (light mode)";
    };
    backgroundImageDark = lib.mkOption {
      type    = lib.types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
      description = "Path to background image (dark mode)";
    };
    screensaverImage = lib.mkOption {
      type    = lib.types.str;
      default = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
      description = "Path to screensaver image";
    };
    gtkTheme = lib.mkOption {
      type    = lib.types.str;
      default = "Breeze-Dark";
      description = "GTK theme name";
    };
    iconTheme = lib.mkOption {
      type    = lib.types.str;
      default = "Papirus-Dark";
      description = "Icon theme name";
    };
    cursorTheme = lib.mkOption {
      type    = lib.types.str;
      default = "Adwaita";
      description = "Cursor theme name";
    };
    cursorSize = lib.mkOption {
      type    = lib.types.int;
      default = 24;
      description = "Cursor size in pixels";
    };
    fontName = lib.mkOption {
      type    = lib.types.str;
      default = "Inter 11";
      description = "Default UI font (name + size)";
    };
    fontMonospace = lib.mkOption {
      type    = lib.types.str;
      default = "JetBrains Mono 10";
      description = "Monospace font used in terminals and editors";
    };
    clockShowDate = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Show date alongside the clock in the top bar";
    };
    clockShowWeekday = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Show weekday alongside the clock in the top bar";
    };
    enableOveramplification = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Allow volume above 100%";
    };
    buttonLayout = lib.mkOption {
      type    = lib.types.str;
      default = "appmenu:minimize,maximize,close";
      description = "Window titlebar button layout";
    };
    numWorkspaces = lib.mkOption {
      type    = lib.types.int;
      default = 4;
      description = "Number of static workspaces";
    };
    dynamicWorkspaces = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Use dynamic workspaces instead of a fixed number";
    };
    enableAnimations = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Enable GNOME shell animations";
    };
    screenBlankTimeout = lib.mkOption {
      type    = lib.types.int;
      default = 300;
      description = "Seconds before screen blanks (0 = never)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ nautilus ];

    dconf.settings = {
      "org/gnome/shell" = {
        favorite-apps = cfg.favoriteApps;
      };
      "org/gnome/desktop/interface" = {
        color-scheme        = "prefer-dark";
        enable-hot-corners  = cfg.enableHotCorners;
        can-change-accels   = true;
        cursor-theme        = cfg.cursorTheme;
        cursor-size         = cfg.cursorSize;
        font-name           = cfg.fontName;
        monospace-font-name = cfg.fontMonospace;
        clock-show-date     = cfg.clockShowDate;
        clock-show-weekday  = cfg.clockShowWeekday;
        enable-animations   = cfg.enableAnimations;
      };
      "org/gnome/desktop/sound" = {
        allow-volume-above-100-percent = cfg.enableOveramplification;
      };
      "org/gnome/desktop/wm/preferences" = {
        workspace-names = cfg.workspaceNames;
        button-layout   = cfg.buttonLayout;
        num-workspaces  = cfg.numWorkspaces;
      };
      "org/gnome/mutter" = {
        dynamic-workspaces = cfg.dynamicWorkspaces;
      };
      "org/gnome/desktop/background" = {
        picture-uri      = cfg.backgroundImage;
        picture-uri-dark = cfg.backgroundImageDark;
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri     = cfg.screensaverImage;
        primary-color   = "#3465a4";
        secondary-color = "#000000";
      };
      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 cfg.screenBlankTimeout;
      };
      "org/gnome/settings-daemon/plugins/power" = {
        sleep-inactive-ac-timeout      = 0;
        sleep-inactive-battery-timeout = 0;
        idle-dim                       = true;
      };
    };

    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      iconTheme.name = cfg.iconTheme;
      theme.name     = cfg.gtkTheme;
      cursorTheme = {
        name = cfg.cursorTheme;
        size = cfg.cursorSize;
      };
    };
  };
}