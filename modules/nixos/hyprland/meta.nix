{
  name = "hyprland";
  description = "Hyprland Wayland compositor desktop environment with waybar, mako, wofi, and greetd display manager";
  category = "desktop";
  tags = [ "hyprland" "wayland" "desktop" "compositor" ];
  provides = [ "my.desktop.hyprland" ];
  expects = [ "my.monitors" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://hyprland.org";
}
