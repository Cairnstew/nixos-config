{ config, lib, flake, ... }:
let
  cfg = config.my.theming.stylix;
  scheme = flake.config.me.colorScheme or { };
in
{
  assertions = [
    {
      assertion = !cfg.enable || (scheme ? base00 && scheme ? base0F);
      message = "Stylix requires me.colorScheme with at least base00-base0F defined in config.nix.";
    }
    {
      assertion = !cfg.enable || (scheme.slug or "") != "";
      message = "Stylix requires me.colorScheme.slug to be set in config.nix.";
    }
  ];
}
