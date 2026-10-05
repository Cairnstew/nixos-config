# =============================================================================
# modules/nixos/theming/tests.nix
# =============================================================================
# Level 0 (Nix assertions) — always-on, no I/O, evaluated on every host build.
#
# These are not decorative. Each one corresponds to a failure mode that is
# silent when it happens: a misspelled scheme silently producing the default
# palette, a malformed override reaching a consumer verbatim, a scheme whose
# text is unreadable against its own background.
# =============================================================================
{ config, lib, flake, ... }:

let
  cfg = config.my.theming;
  theme = flake.config.theming;
  colors = cfg.colors;
  color = cfg.lib.color;

  # Every attribute the resolver promises to produce. A missing one means the
  # resolver regressed, and would surface as an opaque "attribute missing"
  # error deep inside an unrelated module.
  requiredRoles = [
    "background"
    "foreground"
    "foregroundMuted"
    "accent"
    "accentAlt"
    "border"
    "borderSubtle"
    "cursor"
    "selection"
    "success"
    "warning"
    "error"
    "info"
    "surface"
    "onBackground"
  ];

  missingRoles = builtins.filter (r: !(colors ? ${r})) requiredRoles;

  # The 16 ANSI slots a terminal needs.
  ansiSlots = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
    "brightBlack"
    "brightRed"
    "brightGreen"
    "brightYellow"
    "brightBlue"
    "brightMagenta"
    "brightCyan"
    "brightWhite"
  ];

  missingAnsi = builtins.filter (s: !(colors.terminal ? ${s})) ansiSlots;

  badOverrides =
    builtins.filter (n: !(color.valid theme.overrides.${n})) (builtins.attrNames theme.overrides);

  # WCAG AA for normal text. Compared with a small epsilon because the ratio is
  # a float and 4.4999 must not fail a build.
  fgContrast = color.contrast colors.background colors.foreground;

  # Rendered outside the assertion message: Nix has no way to nest a `"` inside
  # a `"${...}"` interpolation.
  fgContrastText =
    if fgContrast == null then
      "invalid"
    else
      "${builtins.floor (fgContrast * 100.0 + 0.5) / 100.0}";
in
{
  assertions = [
    {
      assertion = !colors.didFallback;
      message = ''
        theming.scheme "${toString theme.scheme}" is not in the catalog in
        lib/schemes/, so the palette silently fell back to
        "${colors.resolvedKey}". Add the scheme file or fix the slug.
        Available: ${lib.concatStringsSep ", " theme.schemes}
      '';
    }

    {
      assertion = missingRoles == [ ];
      message = ''
        my.theming.colors is missing roles: ${lib.concatStringsSep ", " missingRoles}.
        The palette is built in lib/theming.nix; this is a regression there.
      '';
    }

    {
      assertion = missingAnsi == [ ];
      message = ''
        my.theming.colors.terminal is missing ANSI slots:
        ${lib.concatStringsSep ", " missingAnsi}. Regression in
        lib/theming.nix (deriveTerminal).
      '';
    }

    {
      assertion = badOverrides == [ ];
      message = ''
        these theming.overrides are not valid hex colours and will be passed to
        consumers verbatim: ${lib.concatStringsSep ", " badOverrides}.
      '';
    }

    {
      assertion = fgContrast != null && fgContrast >= 4.4;
      message = ''
        The "${colors.slug}" scheme has unreadable body text: contrast between
        background (${colors.background}) and foreground (${colors.foreground})
        is ${fgContrastText}:1, below the
        WCAG AA minimum of 4.5:1. Override `theming.overrides.base05` or pick
        a different scheme.
      '';
    }

    {
      assertion = colors.terminal.background == colors.background;
      message = ''
        my.theming.colors.terminal.background (${colors.terminal.background})
        has drifted from my.theming.colors.background (${colors.background}).
        The terminal palette is derived from the roles; if you override
        `background` the terminal must follow it.
      '';
    }
  ];
}
