# Theme record for the nested submodule modules/nixos/hyprland/appearance.
#
# Identity (name/provides/…) is declared once in the parent module's
# meta.nix; this file exists so `tests/theme-coverage_test.nix` can see the
# nested `theme.nix` and check it against the contract.
{
  name = "hyprland-appearance";
  description = "Hyprland decoration (shadow colour)";
  category = "desktop";
  # shadow.color defaults to the palette background at 80% alpha
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
}
