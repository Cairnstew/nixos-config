{
  name = "gnome";
  description = "GNOME desktop environment with GDM, dconf settings, fonts, and home-manager integration";
  category = "desktop";
  tags = [ "gnome" "desktop" "gdm" "wayland" ];
  provides = [ "my.desktop.gnome" ];
  expects = [ "my.homeManager" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://www.gnome.org";
}
