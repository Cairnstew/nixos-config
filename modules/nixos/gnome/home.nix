{ config, pkgs, lib, flake, ... }:
let
  cfg = config.my.desktop.gnome;
  # Get preferences from flake config for defaults
  prefs = flake.config.preferences or { };
  defaults = flake.config.defaults or { };
  scheme = flake.config.me.colorScheme or { };
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
      # Build favorite apps list from defaults config
      default = [
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
    gtkTheme = lib.mkOption {
      type = lib.types.str;
      # Use dark mode preference to select theme
      default = if (prefs.darkMode or true) then "Breeze-Dark" else "Breeze";
      description = "GTK theme name. Defaults based on preferences.darkMode.";
    };
    iconTheme = lib.mkOption {
      type = lib.types.str;
      # Use dark mode preference to select icon theme
      default = if (prefs.darkMode or true) then "Papirus-Dark" else "Papirus";
      description = "Icon theme name. Defaults based on preferences.darkMode.";
    };
    cursorTheme = lib.mkOption {
      type = lib.types.str;
      default = "Adwaita";
      description = "Cursor theme name";
    };
    cursorSize = lib.mkOption {
      type = lib.types.int;
      default = 24;
      description = "Cursor size in pixels";
    };
    fontName = lib.mkOption {
      type = lib.types.str;
      default = "Inter 11";
      description = "Default UI font (name + size)";
    };
    fontMonospace = lib.mkOption {
      type = lib.types.str;
      # Use terminal font from preferences
      default = "${prefs.terminalFont or "JetBrains Mono"} ${toString (prefs.terminalFontSize or 10)}";
      description = "Monospace font used in terminals and editors. Defaults to preferences.terminalFont.";
    };
    clockShowDate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show date alongside the clock in the top bar";
    };
    clockShowWeekday = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show weekday alongside the clock in the top bar";
    };
    enableOveramplification = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow volume above 100%";
    };
    buttonLayout = lib.mkOption {
      type = lib.types.str;
      default = "appmenu:minimize,maximize,close";
      description = "Window titlebar button layout";
    };
    numWorkspaces = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of static workspaces";
    };
    dynamicWorkspaces = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use dynamic workspaces instead of a fixed number";
    };
    enableAnimations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GNOME shell animations";
    };
    screenBlankTimeout = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Seconds before screen blanks (0 = never)";
    };
    sleepInactiveACTimeout = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Seconds before sleep on AC power (0 = never)";
    };
    sleepInactiveACType = lib.mkOption {
      type = lib.types.str;
      default = "nothing";
      description = "Action on AC idle: 'suspend', 'hibernate', 'nothing'";
    };
    sleepInactiveBatteryTimeout = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "Seconds before sleep on battery power (0 = never)";
    };
    sleepInactiveBatteryType = lib.mkOption {
      type = lib.types.str;
      default = "nothing";
      description = "Action on battery idle: 'suspend', 'hibernate', 'nothing'";
    };
    powerButtonAction = lib.mkOption {
      type = lib.types.str;
      default = "nothing";
      description = "Power button action: 'suspend', 'hibernate', 'interactive', 'nothing'";
    };
    idleBrightness = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Screen brightness percentage when idle-dim activates";
    };
    ambientEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable ambient light sensor for auto-brightness";
    };
    lockEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Lock screen on idle/suspend";
    };
    lockDelay = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Delay in seconds after screensaver before locking (0 = immediate)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Use the default file manager from config
    home.packages = with pkgs; [
      (if (defaults.fileManager or "nautilus") == "nautilus" then nautilus else pkgs.${defaults.fileManager})
    ];

    dconf.settings = {
      # ── Always-applied settings (non-theming) ──────────────────────────
      "org/gnome/shell" = {
        favorite-apps = cfg.favoriteApps;
      };
      "org/gnome/desktop/sound" = {
        allow-volume-above-100-percent = cfg.enableOveramplification;
      };
      "org/gnome/desktop/wm/preferences" = {
        workspace-names = cfg.workspaceNames;
        button-layout = cfg.buttonLayout;
        num-workspaces = cfg.numWorkspaces;
      };
      "org/gnome/mutter" = {
        dynamic-workspaces = cfg.dynamicWorkspaces;
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri = cfg.screensaverImage;
        primary-color = scheme.accent or "#3465a4";
        secondary-color = scheme.background or "#000000";
        lock-enabled = cfg.lockEnabled;
        lock-delay = lib.hm.gvariant.mkUint32 cfg.lockDelay;
      };
      "org/gnome/desktop/session" = {
        idle-delay = lib.hm.gvariant.mkUint32 cfg.screenBlankTimeout;
      };
      "org/gnome/settings-daemon/plugins/power" = {
        ambient-enabled = cfg.ambientEnabled;
        idle-brightness = cfg.idleBrightness;
        idle-dim = true;
        power-button-action = cfg.powerButtonAction;
        power-saver-profile-on-low-battery = true;
        sleep-inactive-ac-timeout = cfg.sleepInactiveACTimeout;
        sleep-inactive-ac-type = cfg.sleepInactiveACType;
        sleep-inactive-battery-timeout = cfg.sleepInactiveBatteryTimeout;
        sleep-inactive-battery-type = cfg.sleepInactiveBatteryType;
      };

      # ── Theming settings (disabled when Stylix is active) ──────────────
    } // lib.optionalAttrs (!(config.stylix.enable or false)) {
      "org/gnome/desktop/interface" = {
        color-scheme = if (prefs.darkMode or true) then "prefer-dark" else "prefer-light";
        enable-hot-corners = cfg.enableHotCorners;
        can-change-accels = true;
        cursor-theme = cfg.cursorTheme;
        cursor-size = cfg.cursorSize;
        font-name = cfg.fontName;
        monospace-font-name = cfg.fontMonospace;
        clock-show-date = cfg.clockShowDate;
        clock-show-weekday = cfg.clockShowWeekday;
        enable-animations = cfg.enableAnimations;
      };
      "org/gnome/desktop/background" = {
        picture-uri = cfg.backgroundImage;
        picture-uri-dark = cfg.backgroundImageDark;
      };
    };

    # GTK theming (disabled when Stylix is active)
    gtk = lib.mkIf (!(config.stylix.enable or false)) {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = prefs.darkMode or true;
      iconTheme.name = cfg.iconTheme;
      theme.name = cfg.gtkTheme;
      cursorTheme = {
        name = cfg.cursorTheme;
        size = cfg.cursorSize;
      };
    };
  };
}
