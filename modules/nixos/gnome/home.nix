{ config, pkgs, lib, flake, ... }:
let
  cfg = config.my.desktop.gnome;
  defaults = flake.config.defaults or { };
in
{
  # Option declarations live in ./home-options.nix (module-layout conformance,
  # M2/M3); every colour lives in ./theme.nix.
  imports = [
    ./home-options.nix
    ./theme.nix
  ];

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

      "org/gnome/desktop/interface" = {
        # Non-theming interface preferences only; colour-scheme, fonts and the
        # cursor live in ./theme.nix (which stylix overrides when enabled).
        enable-hot-corners = cfg.enableHotCorners;
        can-change-accels = true;
        clock-show-date = cfg.clockShowDate;
        clock-show-weekday = cfg.clockShowWeekday;
        enable-animations = cfg.enableAnimations;
      };
      "org/gnome/desktop/background" = {
        picture-uri = cfg.backgroundImage;
        picture-uri-dark = cfg.backgroundImageDark;
      };
    };
  };
}
