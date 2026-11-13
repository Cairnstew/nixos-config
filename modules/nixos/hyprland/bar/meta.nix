# Theme record for the nested submodule modules/nixos/hyprland/bar.
#
# Identity (name/provides/…) is declared once in the parent module's
# meta.nix; this file exists so `tests/theme-coverage_test.nix` can see the
# nested `theme.nix` and check it against the contract.
{
  name = "hyprland-bar";
  description = "waybar status bar";
  category = "desktop";
  # style.css is generated from the palette; custom-module `format` examples take roles
  theme = {
    kind = "gui";
    mechanism = "css-inject";
    file = "theme.nix";
  };
}
