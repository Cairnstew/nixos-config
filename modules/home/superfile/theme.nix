# superfile theming — a full theme TOML generated from the shared palette.
#
# superfile reads `$XDG_CONFIG_HOME/superfile/theme/<name>.toml` and selects one
# with `settings.theme`. The key set below mirrors the theme file superfile
# ships (`src/superfile_config/theme/catppuccin-mocha.toml`); every colour is a
# role, so switching `theming.scheme` restyles the file manager.
#
# `code_syntax_highlight` is a *chroma* style name, not a colour: the scheme
# slug is passed through (chroma knows the Catppuccin flavours, `dracula` and
# `nord`) with the two catalog slugs chroma spells differently aliased.
{ config, lib, ... }:

let
  cfg = config.my.programs.superfile;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  color = themeLib.color;

  chromaAlias = {
    gruvbox-dark = "gruvbox";
    tokyo-night = "tokyonight-night";
  };

  mkTheme =
    p:
    let
      # Text colour for a solid accent-coloured surface (modal buttons): the
      # palette's own onBackground only covers the page background.
      on = bg: color.bestForeground bg [
        p.background
        p.foreground
        "#ffffff"
        "#000000"
      ];
    in
    {
      code_syntax_highlight = t.syntaxTheme;

      full_screen_fg = p.foreground;
      full_screen_bg = p.background;

      # accent → syntax keyword, matching upstream's blue→mauve gradient.
      gradient_color = [
        p.accent
        p.syntaxKeyword
      ];

      file_panel_fg = p.foreground;
      file_panel_bg = p.background;
      file_panel_border = p.border;
      file_panel_border_active = p.accent;
      file_panel_top_directory_icon = p.success;
      file_panel_top_path = p.accent;
      file_panel_item_selected_fg = p.accent;
      file_panel_item_selected_bg = p.backgroundElement;

      footer_fg = p.foreground;
      footer_bg = p.background;
      footer_border = p.border;
      footer_border_active = p.success;

      sidebar_fg = p.foreground;
      sidebar_bg = p.background;
      sidebar_title = p.accentAlt;
      sidebar_border = p.background;
      sidebar_border_active = p.error;
      sidebar_item_selected_fg = p.accent;
      sidebar_item_selected_bg = p.backgroundElement;
      sidebar_divider = p.borderStrong;

      modal_fg = p.foreground;
      modal_bg = p.surface;
      modal_border_active = p.borderStrong;
      modal_cancel_fg = on p.error;
      modal_cancel_bg = p.error;
      modal_confirm_fg = on p.success;
      modal_confirm_bg = p.success;

      help_menu_hotkey = p.info;
      help_menu_title = p.syntaxKeyword;

      cursor = p.cursor;
      correct = p.success;
      inherit (p) error;
      hint = p.info;
      cancel = p.warning;
    };
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.superfile.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        name = lib.mkOption {
          type = lib.types.str;
          default = "nixos-palette";
          description = ''
            File name (without `.toml`) of the generated theme — also what
            `settings.theme` is set to. A theme of the same name in
            `my.programs.superfile.themes` wins.
          '';
        };

        syntaxTheme = lib.mkOption {
          type = lib.types.str;
          default = chromaAlias.${config.palette.slug} or config.palette.slug;
          defaultText = lib.literalExpression "the active scheme slug (aliased for gruvbox-dark / tokyo-night)";
          description = ''
            Chroma style used for code previews. Scheme slugs already match
            chroma's names for the Catppuccin flavours, `dracula` and `nord`;
            `gruvbox-dark` → `gruvbox` and `tokyo-night` → `tokyonight-night`
            are aliased. An unknown name falls back to chroma's default.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          readOnly = true;
          default = mkTheme config.palette;
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = "The generated superfile theme table (written as `<name>.toml`).";
        };
      };
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    # Per-key default: a user-supplied theme of the same name wins, and other
    # themes still merge in.
    my.programs.superfile.themes.${t.name} = lib.mkDefault t.settings;
    my.programs.superfile.settings.theme = lib.mkDefault t.name;
  };
}
