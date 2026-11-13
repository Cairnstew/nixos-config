# Zed theming — maps the shared palette onto Zed's theme-extension format.
#
# This file owns `my.programs.zed-editor.theme` (the standard `mkAppTheme`
# shape) and the only colour code in the module: config.nix used to generate
# this ~135-line theme inline. See docs/decisions/2026-11-13-theme-nix.md.
{ config, lib, ... }:

let
  cfg = config.my.programs.zed-editor;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  p = t.palette;
  b = p.base16;
  term = p.terminal;
  color = themeLib.color;

  # Wrap a hex string in HighlightStyleContent struct
  mkHighlight = c: { color = c; };

  # Auto-generate a Zed theme from the resolved palette.
  # Format: each theme file is a Zed theme extension manifest with a "themes" array
  # See https://zed.dev/docs/extensions/themes
  #
  # Appearance follows the active scheme's polarity rather than
  # `preferences.darkMode`, so the two cannot disagree.
  generated =
    if p ? slug then {
      "${p.slug}" = {
        name = p.slug;
        author = "auto-generated from my.theming.colors (${p.family})";
        themes = [
          {
            name = p.slug;
            appearance = if p.polarity == "dark" then "dark" else "light";
            style = {
              background = b.base00;
              foreground = b.base05;
              borders = b.base03;
              border = b.base03;
              drop_target = b.base0D;
              element = b.base02;
              element_active = b.base03;
              panel = {
                background = b.base01;
                border = b.base03;
                footer = {
                  background = b.base01;
                  border = b.base03;
                };
                header = {
                  background = b.base01;
                  border = b.base03;
                };
              };
              editor = {
                background = b.base00;
                foreground = b.base05;
                invisible = b.base03;
                line_wrap_guide = b.base03;
                active_line = b.base01;
                highlight_row_background = b.base01;
                bracket_matching = b.base02;
                gutter = {
                  background = b.base00;
                  foreground = b.base04;
                };
              };
              syntax = {
                comment = mkHighlight (b.base03);
                keyword = mkHighlight (b.base0E);
                function = mkHighlight (b.base0D);
                variable = mkHighlight (b.base05);
                string = mkHighlight (b.base0B);
                number = mkHighlight (b.base0F);
                type = mkHighlight (b.base0A);
                operator = mkHighlight (b.base0C);
                punctuation = mkHighlight (b.base05);
                constant = mkHighlight (b.base0F);
                tag = mkHighlight (b.base08);
                attribute = mkHighlight (b.base0D);
                embedded = mkHighlight (b.base0C);
                link_text = mkHighlight (b.base0D);
                link_uri = mkHighlight (b.base0D);
                markup = {
                  bold = {
                    color = b.base0E;
                    font_weight = 700;
                  };
                  italic = {
                    color = b.base09;
                    font_style = "italic";
                  };
                  strikethrough = mkHighlight (b.base03);
                  quote = mkHighlight (b.base03);
                  heading = {
                    color = b.base0D;
                    font_weight = 700;
                  };
                  list = mkHighlight (b.base0C);
                  raw_inline = mkHighlight (b.base0B);
                  raw_block = mkHighlight (b.base01);
                };
              };
              status_bar = {
                background = b.base01;
                foreground = b.base05;
              };
              title_bar = {
                background = b.base00;
                foreground = b.base05;
              };
              scrollbar = {
                thumb = {
                  background = b.base03;
                  border = b.base03;
                };
                track = {
                  background = b.base00;
                  border = b.base00;
                };
              };
              tab = {
                active_background = b.base01;
                active_foreground = b.base05;
                inactive_background = b.base00;
                inactive_foreground = b.base04;
              };
              terminal = {
                background = b.base00;
                foreground = b.base05;
                # The 16 ANSI slots, from the shared terminal palette.
                # These two entries used to be the hardcoded literals "585b70"
                # and "a6adc8" — Catppuccin Mocha and Frappé values respectively,
                # so they disagreed with the rest of the block and would have
                # survived a scheme switch as stale colours.
                ansi = map color.toBase16 [
                  term.black
                  term.red
                  term.green
                  term.yellow
                  term.blue
                  term.magenta
                  term.cyan
                  term.white
                  term.brightBlack
                  term.brightRed
                  term.brightGreen
                  term.brightYellow
                  term.brightBlue
                  term.brightMagenta
                  term.brightCyan
                  term.brightWhite
                ];
              };
            };
          }
        ];
      };
    } else { };

  # Merge user custom themes on top of the generated one (user overrides win).
  mergedThemes = lib.recursiveUpdate generated t.customThemes;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.zed-editor.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions = {
      name = lib.mkOption {
        type = lib.types.either lib.types.str (lib.types.submodule {
          options = {
            dark = lib.mkOption {
              type = lib.types.str;
              description = "Theme name for dark mode.";
            };
            light = lib.mkOption {
              type = lib.types.str;
              description = "Theme name for light mode.";
            };
            mode = lib.mkOption {
              type = lib.types.enum [ "dark" "light" "system" ];
              default = "dark";
              description = "Which theme mode to use.";
            };
          };
        });
        default = config.my.theming.colors.slug or "catppuccin-mocha";
        description = ''
          Theme to use. Can be a string (single theme) or an attrset with
          dark/light variants. Defaults to the active scheme's slug.
        '';
      };

      customThemes = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        default = { };
        description = ''
          Custom Zed theme definitions, merged on top of the generated theme
          (user overrides win). Add your own themes here or override the
          generated one.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    programs.zed-editor.themes = mergedThemes;
  };
}
