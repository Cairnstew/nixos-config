{
  name = "gnome";
  description = "GNOME desktop environment with GDM, dconf settings, fonts, and home-manager integration";
  category = "desktop";
  tags = [ "gnome" "desktop" "gdm" "wayland" ];
  provides = [
    "my.desktop.gnome"
    "my.desktop.gnome.theme"
  ];
  expects = [ "my.homeManager" ];
  complexity = "medium";
  # Home-Manager side (home.nix). dconf colour-scheme/accent + GTK names; the
  # whole block is skipped when stylix owns GTK.
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
  tested = true;
  maintainer = "seanc";
  homepage = "https://www.gnome.org";
}
