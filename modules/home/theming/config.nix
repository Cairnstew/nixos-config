# my.theming.* — assignments.
#
# Prefers the flake-resolved palette (nixos-unified hands flake-parts' config
# to modules as `flake.config`, and every Home Manager module in this repo
# already takes `flake`). When there is no flake — a standalone Home Manager
# configuration — it resolves the catalog default directly from lib/theming.nix,
# so the option surface never disappears.
#
# Either way the *source of truth* is lib/theming.nix: this module only
# re-exposes its result, so the NixOS side and the home side can never drift.
{ lib, flake ? { config = { }; }, ... }:

let
  themingLib = import ../../../lib/theming.nix { inherit lib; };

  flakeTheme = if flake.config ? theming then flake.config.theming else null;

  # Same selection + overrides the NixOS side uses, so a standalone evaluation
  # lands on the identical palette rather than an arbitrary one.
  colors =
    if flakeTheme == null then
      themingLib.mkColors { }
    else
      flakeTheme.colors;
in
{
  config.my.theming = {
    inherit colors;
    lib = themingLib;
    scheme = colors.slug;
    schemeUnderscored = lib.replaceStrings [ "-" ] [ "_" ] colors.slug;
    polarity = colors.polarity;
  };
}
