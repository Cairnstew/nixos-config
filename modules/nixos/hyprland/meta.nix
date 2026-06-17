{
  name = "hyprland";
  description = "Hyprland Wayland compositor desktop environment with modular tool submodules: waybar, wofi, mako, wallpapers (hyprpaper/awww/mpvpaper/waypaper), swaylock, grim+slurp, wl-clipboard, greetd, pipewire, xdg-portal, and opt-in hypridle, hyprpicker, hyprsunset, pyprland";
  category = "desktop";
  tags = [ "hyprland" "wayland" "desktop" "compositor" "waybar" "wofi" "mako" "greetd" ];
  provides = [
    "my.desktop.hyprland"
    "my.desktop.hyprland.core"
    "my.desktop.hyprland.bar"
    "my.desktop.hyprland.launcher"
    "my.desktop.hyprland.notifications"
    "my.desktop.hyprland.wallpapers"
    "my.desktop.hyprland.lockscreen"
    "my.desktop.hyprland.screenshot"
    "my.desktop.hyprland.clipboard"
    "my.desktop.hyprland.portal"
    "my.desktop.hyprland.displayManager"
    "my.desktop.hyprland.audio"
    "my.desktop.hyprland.utilities"
    "my.desktop.hyprland.nvidia"
    "my.desktop.hyprland.idle"
    "my.desktop.hyprland.colorpicker"
    "my.desktop.hyprland.nightLight"
    "my.desktop.hyprland.pyprland"
    "my.desktop.hyprland.awww"
  ];
  expects = [ "my.monitors" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://hyprland.org";
}
