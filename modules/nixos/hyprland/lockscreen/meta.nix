# Theme record for the nested submodule modules/nixos/hyprland/lockscreen.
#
# Identity (name/provides/…) is declared once in the parent module's
# meta.nix; this file exists so `tests/theme-coverage_test.nix` can see the
# nested `theme.nix` and check it against the contract.
{
  name = "hyprland-lockscreen";
  description = "swaylock / hyprlock screen locker";
  category = "desktop";
  # swaylock takes hashless hex, hyprlock takes rgba(); both generated from the palette
  theme = {
    kind = "gui";
    mechanism = "native";
    file = "theme.nix";
  };
}
