# my.theming.* — read-only view of the resolved palette for NixOS modules.
#
# There is deliberately no `enable` option here. This module has no side
# effects: it only mirrors data that lib/theming.nix already computed from
# `theming.scheme` in the repo-root config.nix. Gating it would mean every
# consumer module needs `lib.mkIf cfg.enable`, and a host that forgot to enable
# it would get "attribute 'accent' missing" instead of a default palette.
# Theming *behaviour* (auto-generating themes for applications) is gated
# separately by my.theming.stylix.enable.
{ lib, ... }:

{
  options.my.theming = {
    colors = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        The resolved colour palette for this system. This is the read API
        every NixOS module should use.

          my.theming.colors.background    — window / editor background
          my.theming.colors.foreground    — primary text
          my.theming.colors.accent        — links, focus, highlights
          my.theming.colors.error         — errors, destructive actions
          my.theming.colors.terminal.blue — one of 16 ANSI colours
          my.theming.colors.base16        — hashless base16, for stylix

        Change the palette system-wide with `theming.scheme` in the repo-root
        config.nix, or per-role with `theming.overrides`.
      '';
      example = lib.literalExpression ''
        {
          programs.rofi = {
            enable = true;
            theme = {
              background = my.theming.colors.background;
              foreground = my.theming.colors.foreground;
              selected = my.theming.colors.accent;
            };
          };
        }
      '';
    };

    lib = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      description = ''
        Pure colour maths, usable from any module without importing anything:

          my.theming.lib.color.contrast bg fg   — WCAG contrast ratio (1-21)
          my.theming.lib.color.mix a b 0.5      — blend two colours
          my.theming.lib.color.lighten hex 0.2  — lighten by 20%
          my.theming.lib.color.darken hex 0.2
          my.theming.lib.color.alpha hex 0.5    — add an alpha channel
          my.theming.lib.color.ensureContrast fg bg 4.5
          my.theming.lib.color.bestForeground bg [ fg1 fg2 ]

        Implemented in lib/color.nix (no flake or module dependency), so the
        WCAG maths is unit-tested in isolation — see lib/README.md.
      '';
    };

    scheme = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Slug of the scheme actually in use, e.g. "catppuccin-mocha". For
        programs that take a theme *name* (helix, ghostty, zed).
      '';
    };

    polarity = lib.mkOption {
      type = lib.types.enum [ "dark" "light" ];
      readOnly = true;
      description = "Whether the active scheme is a dark or a light theme.";
    };

    schemes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Every scheme slug available in lib/schemes/.";
    };
  };
}
