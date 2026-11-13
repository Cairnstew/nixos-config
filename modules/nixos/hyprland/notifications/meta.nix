# Theme record for the nested submodule modules/nixos/hyprland/notifications.
#
# Identity (name/provides/…) is declared once in the parent module's
# meta.nix; this file exists so `tests/theme-coverage_test.nix` can see the
# nested `theme.nix` and check it against the contract.
{
  name = "hyprland-notifications";
  description = "mako notification daemon";
  category = "desktop";
  # flat key=value config, colours interpolated from the palette
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
}
