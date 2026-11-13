# Theme record for the nested submodule modules/nixos/hyprland/display-manager.
#
# Identity (name/provides/…) is declared once in the parent module's
# meta.nix; this file exists so `tests/theme-coverage_test.nix` can see the
# nested `theme.nix` and check it against the contract.
{
  name = "hyprland-display-manager";
  description = "SDDM / greetd display manager";
  category = "desktop";
  # SDDM colours live in its theme package; the Catppuccin flavour/accent (and therefore the theme dir) follows the scheme
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
}
