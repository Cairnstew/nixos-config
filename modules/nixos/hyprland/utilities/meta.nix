# Theme record for the nested submodule modules/nixos/hyprland/utilities.
#
# Identity (name/provides/…) is declared once in the parent module's
# meta.nix; this file exists so `tests/theme-coverage_test.nix` can see the
# nested `theme.nix` and check it against the contract.
{
  name = "hyprland-utilities";
  description = "desktop utilities (GTK3 settings)";
  category = "desktop";
  # GTK3 has no per-colour hook; polarity + theme/icon names, and GTK names are skipped when stylix owns GTK
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
}
