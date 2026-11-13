{ lib, ... }:
{
  options.my.desktop.hyprland.utilities = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable desktop utilities bundled with Hyprland:
        - polkit-gnome: authentication agent for privilege escalation
        - thunar: GUI file manager (with archive plugin + volume manager). Not
          the SUPER+E target — that keybind runs the terminal file manager from
          `my.desktop.hyprland.fileManager`; thunar stays as the GUI/xdg
          `inode/directory` handler and the workspace-3 autostart window.
        - gvfs: virtual filesystem (trash, remote mounts, etc.)
        - tumbler: thumbnail service for file manager
        - NetworkManager applet: tray-based network management
        - Fonts: JetBrainsMono (Nerd Font), Fira Code, Noto, Liberation
        - brightnessctl: backlight control
        - playerctl: media player controls
        - imv: image viewer
        - mpv: video player
        - GTK dark theme configuration
      '';
    };
  };
}
