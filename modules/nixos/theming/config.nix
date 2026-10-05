# my.theming.* — assignments.
#
# This module wires no files and starts no services; it exists purely to make
# the flake-resolved palette reachable as `my.theming.*` inside the NixOS
# module system, so consumers never have to thread `flake` through their
# argument list. The palette itself is computed in lib/theming.nix from
# `theming.scheme` / `theming.overrides` (repo-root config.nix) and arrives
# here fully resolved via flake-parts' config, which nixos-unified hands to
# modules as `flake.config`.
{ flake, ... }:

let
  theme = flake.config.theming;
in
{
  config.my.theming = {
    colors = theme.colors;
    lib = theme.lib;
    scheme = theme.colors.slug;
    polarity = theme.colors.polarity;
    schemes = theme.schemes;
  };
}
