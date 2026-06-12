{
  name = "gnome-extension";
  description = "Declarative custom GNOME Shell extensions with inline Nix configuration injection";
  category = "desktop";
  tags = [ "gnome" "shell" "extension" "desktop" "ui" ];
  provides = [ "my.gnomeExtensions.custom" ];
  expects = [ ];
  complexity = "simple";
  tested = true;
  homepage = "https://gjs.guide/extensions/";
  maintainer = "seanc";
}
