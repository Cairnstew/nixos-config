{ lib, ... }:
{
  options.my.desktop.hyprland.pyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable pyprland IPC plugin system (scratchpads, expose, monitors, etc.).";
    };
    plugins = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [
        "scratchpads"
        "expose"
        "layout_center"
        "monitors"
        "shift_monitors"
        "workspaces_follow_focus"
        "toggle_dpms"
        "wallpapers"
        "magnify"
        "lost_windows"
        "shortcuts_menu"
        "fetch_client_menu"
        "system_notifier"
        "fcitx5_switcher"
      ]);
      default = [ ];
      example = [ "scratchpads" "expose" "monitors" ];
      description = "List of pyprland plugins to enable. See https://hyprland-community.github.io/pyprland/";
    };
  };
}
