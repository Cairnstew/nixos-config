{ lib, ... }:
{
  options.my.desktop.gnome = {
    # G1: my.desktop.gnome.* was declared in both NixOS options.nix and HM home.nix (imported via
    # home-manager.sharedModules in config.nix) with drifted defaults (e.g. enableHotCorners true here
    # vs false in home.nix). home.nix is the sole owner of the desktop-options set; this NixOS scope
    # keeps only `enable`, which is consumed in NixOS scope (config.nix, tests.nix, stylix, mouse).
    enable = lib.mkEnableOption "GNOME desktop environment with GDM display manager";
  };
}
