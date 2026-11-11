# Option declarations for my.desktop.gnome in home-manager scope.
# Split out of home.nix for module-layout conformance (M2/M3): options live in
# this sibling file, config stays in home.nix. `prefs`/`defaults` are re-derived
# here (not shared) because home.nix's config half also needs them.
{ lib, flake, ... }:
let
  # Get preferences from flake config for defaults
  prefs = flake.config.preferences or { };
  defaults = flake.config.defaults or { };
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
}
