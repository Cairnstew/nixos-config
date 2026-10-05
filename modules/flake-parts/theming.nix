# =============================================================================
# modules/flake-parts/theming.nix — the flake-level theme schema (SSOT)
# =============================================================================
# Purpose: be the ONE place a colour scheme is selected and resolved. Every
#          consumer in the repo — NixOS modules, Home Manager modules,
#          flake-parts layers, scripts, and `nix eval` — reads the resolved
#          palette from here, so there is exactly one answer to "what colour is
#          the accent on this system".
#
# Values are set in the repo-root `config.nix` under `theming = { ... };`;
# this file only declares the schema and derives the result.
#
# Outputs (config, not perSystem — theming is host-independent):
#   - config.theming.colors      resolved palette: roles + base16 + terminal
#   - config.theming.lib         the pure color/theming helper functions
#   - config.theming.schemes     names of every scheme in the catalog
#   - config.theming.available   the raw catalog, keyed by name
#   - flake.lib.color            the same helpers, for non-module consumers
#   - flake.lib.theming
#
# Auto-imported by flake.nix (every modules/flake-parts/*.nix is a part).
# Resolution itself lives in ../../lib/theming.nix, which has no dependency on
# the flake or on any module system.
# =============================================================================

{ config
, lib
, ...
}:

let
  # Named `themingLib`, not `theming`, so the option named `theming.lib` cannot
  # be confused with the flake-parts `lib` — `inherit lib;` here would silently
  # expose flake-parts' library instead of the colour helpers.
  themingLib = import ../../lib/theming.nix { inherit lib; };
  cfg = config.theming;

  # Resolved once and shared by every consumer below.
  colors = themingLib.mkColors {
    scheme = cfg.scheme;
    overrides = cfg.overrides;
  };
in
{
  options.theming = {
    scheme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      example = "catppuccin-latte";
      description = ''
        Name of a scheme from the catalog in `lib/schemes/`.

        Adding a scheme means dropping one `.nix` file into `lib/schemes/` —
        there is no registry to update. Use
        `nix eval .#theming.schemes` to list what is available.
      '';
    };

    overrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        {
          # Override a base16 slot and every role derived from it follows.
          base00 = "#000000";
          # Override a single role; nothing else moves.
          accent = "#ff0055";
        }
      '';
      description = ''
        Per-role or per-slot colour overrides, applied on top of the selected
        scheme. Values must be hex colours.

        Overrides targeting `base00`-`base0F` replace the raw palette and the
        semantic roles are re-derived from it. Overrides targeting any other
        role name are applied afterwards and win outright. Later always wins.
      '';
    };

    colors = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        The resolved palette. This is the primary read API for every module.

        Beyond `base00`-`base0F` it carries:

        - semantic roles (`background`, `foreground`, `accent`, `error`,
          `warning`, `success`, `info`, `border`, `selection`, `surface`,
          `foregroundMuted`, `syntax*`, `diff*`, ...)
        - `terminal` — the 16 ANSI colours plus cursor/selection
        - `base16` — the hashless palette stylix and base16 tooling expects
        - `onBackground` — a text colour guaranteed legible on `background`
        - identity: `slug`, `name`, `family`, `variant`, `polarity`, `isDark`

        Example: `config.theming.colors.accent`
      '';
    };

    lib = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      description = ''
        The pure theming helpers: `{ color, schemes, mkColors, ... }`.

        `color` carries parse/luminance/contrast/mix/lighten/darken/alpha/
        ensureContrast. `mkColors` resolves an arbitrary scheme by name,
        which is what a theme-picker app or a one-off script wants.
      '';
    };

    schemes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Names of every scheme in the catalog, sorted.";
    };

    available = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      readOnly = true;
      description = ''
        The raw scheme catalog keyed by name — each entry's own
        `base00`-`base0F` and metadata, unresolved. Use `colors` for the
        derived palette; this is the input to the derivation.
      '';
    };
  };

  config.theming = {
    # `schemes` in lib/theming.nix is the catalog attrset; `schemeNames` is
    # the list of slugs, which is what this option's type calls for.
    schemes = themingLib.schemeNames;
    available = themingLib.schemes;
    colors = colors;
    lib = themingLib;
  };
}
