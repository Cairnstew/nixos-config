# Level 0 assertions for the Home Manager theming module.
#
# The palette is inert data, so the checks here are cheap and run on every host.
# They mirror modules/nixos/theming/tests.nix: a standalone HM evaluation takes
# a different path to the palette (no flake), and this is what proves that path
# still produces a complete, legible palette.
{ config, lib, ... }:

let
  cfg = config.my.theming;
  colors = cfg.colors;
  color = cfg.lib.color;

  requiredRoles = [
    "background"
    "foreground"
    "accent"
    "error"
    "border"
    "cursor"
    "selection"
    "onBackground"
  ];

  missingRoles = builtins.filter (r: !(colors ? ${r})) requiredRoles;

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

  fgContrast = color.contrast colors.background colors.foreground;
  fgContrastText =
    if fgContrast == null then
      "invalid"
    else
      "${builtins.floor (fgContrast * 100.0 + 0.5) / 100.0}";
in
{
  assertions = [
    {
      assertion = missingRoles == [ ];
      message = "my.theming.colors is missing roles: ${lib.concatStringsSep ", " missingRoles}. Regression in lib/theming.nix.";
    }

    {
      assertion = missingAnsi == [ ];
      message = "my.theming.colors.terminal is missing ANSI slots: ${lib.concatStringsSep ", " missingAnsi}. Regression in lib/theming.nix.";
    }

    {
      assertion = colors.slug != "";
      message = ''
        my.theming.colors.slug is empty, so programs that reference a theme by
        name (helix, zed) would get an empty string. Regression in
        lib/theming.nix.
      '';
    }

    {
      # Guards a real trap: the scheme file's declared `polarity` and the
      # luminance of its own background can disagree, and the desktop reads one
      # while stylix reads the other.
      assertion = colors.isDark == (colors.polarity == "dark");
      message = ''
        The "${colors.slug}" scheme declares polarity "${colors.polarity}" but
        its background ${colors.background} is actually
        ${if colors.isDark then "dark" else "light"}. Fix the `polarity` field
        in lib/schemes/${colors.slug}.nix.
      '';
    }

    {
      assertion = fgContrast != null && fgContrast >= 4.4;
      message = ''
        The "${colors.slug}" scheme has unreadable body text: ${fgContrastText}:1
        between background (${colors.background}) and foreground
        (${colors.foreground}), below the WCAG AA minimum of 4.5:1.
      '';
    }
  ];
}
