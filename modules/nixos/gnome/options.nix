{ lib, flake, ... }:
{
  options.my.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment with GDM display manager";

    favoriteApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = with flake.config; [
        "${defaults.browser or "firefox"}.desktop"
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
      default = true;
      description = "Enable GNOME hot corners";
    };

    backgroundImage = lib.mkOption {
      type = lib.types.path;
      default = /run/current-system/sw/share/backgrounds/gnome/vnc-l.png;
      description = "Background image (light mode)";
    };

    gtkTheme = lib.mkOption {
      type = lib.types.str;
      default = if (flake.config.preferences.darkMode or true) then "Breeze-Dark" else "Breeze";
      description = "GTK theme name";
    };

    iconTheme = lib.mkOption {
      type = lib.types.str;
      default = if (flake.config.preferences.darkMode or true) then "Papirus-Dark" else "Papirus";
      description = "Icon theme name";
    };

    cursorTheme = lib.mkOption {
      type = lib.types.str;
      default = "Adwaita";
      description = "Cursor theme name";
    };

    fontName = lib.mkOption {
      type = lib.types.str;
      default = "Inter 11";
      description = "Default UI font";
    };

    fontMonospace = lib.mkOption {
      type = lib.types.str;
      default = "${flake.config.preferences.terminalFont or "JetBrains Mono"} ${toString (flake.config.preferences.terminalFontSize or 10)}";
      description = "Monospace font";
    };

    numWorkspaces = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of static workspaces";
    };
  };
}
