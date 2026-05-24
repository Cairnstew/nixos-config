{
  name = "hyprland";
  description = "Hyprland Wayland compositor with home-manager integration";
  category = "desktop";
  tags = [ "hyprland" "wayland" "compositor" "desktop" ];
  provides = [ "my.desktop.hyprland" ];
  expects = [ "my.homeManager" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://hyprland.org";
}
