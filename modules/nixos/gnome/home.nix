{ config, pkgs, lib, flake, ... }:
let
  cfg = config.my.desktop.gnome;
  # Get preferences from flake config for defaults
  prefs = flake.config.preferences or { };
  defaults = flake.config.defaults or { };
  # Resolved palette (modules/home/theming). Accent colours for the GNOME
  # accent-colour scheme come from the shared theme rather than a local
  # base16 read.
  theme = config.my.theming.colors or { };
in
{
  # Option declarations live in ./home-options.nix (module-layout conformance, M2/M3).
  imports = [ ./home-options.nix ];

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
        primary-color = theme.accent or "#3465a4";
        secondary-color = theme.background or "#000000";
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
        color-scheme = if (config.my.theming.polarity or "dark") == "dark" then "prefer-dark" else "prefer-light";
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
