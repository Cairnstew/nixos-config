# Ghostty theming — generates a named Ghostty theme from the shared palette.
#
# The generated theme is selected by default (`settings.theme`), so switching
# `theming.scheme` changes the terminal instead of leaving Catppuccin behind.
# `customThemes` still wins over the generated entry for the same name.
{ config, lib, ... }:

let
  cfg = config.my.programs.ghostty;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  p = t.palette;

  # Ghostty theme files take hashless hex for colours and `N=#rrggbb` strings
  # for the 16-colour palette.
  hex = themeLib.color.toBase16;

  generated = {
    background = [ (hex p.background) ];
    foreground = [ (hex p.foreground) ];
    cursor-color = [ (hex p.cursor) ];
    selection-background = [ (hex p.selection) ];
    selection-foreground = [ (hex p.selectionText) ];
    palette = themeLib.ansi16 p;
  };
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.ghostty.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions = {
      name = lib.mkOption {
        type = lib.types.str;
        default = config.my.theming.colors.slug or "catppuccin-mocha";
        description = ''
          Ghostty theme to activate. Defaults to the generated theme (the active
          scheme's slug); set a Ghostty built-in name to use that instead.
        '';
      };

      customThemes = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = { };
        description = ''
          Extra Ghostty theme definitions, merged over the generated theme
          (same name wins).
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    programs.ghostty = {
      settings.theme = lib.mkDefault t.name;
      themes = lib.mkMerge [
        { ${p.slug} = generated; }
        (lib.mkDefault t.customThemes)
      ];
    };
  };
}
