# Helix theming — generates a full theme from the shared palette.
#
# Previously this module pointed `settings.theme` at
# `my.theming.schemeUnderscored`, which only works when the active scheme is
# also a built-in Helix theme (catppuccin_mocha, dracula, nord). Any other
# scheme silently fell back to Helix's default. Generating the theme makes the
# editor follow `theming.scheme` for every scheme in the catalog.
#
# Zellij is deliberately not given a generated theme: its default theme uses
# the terminal's ANSI colours, which ghostty's generated theme already sets, so
# a second palette here would be a second source of truth.
{ config, lib, ... }:

let
  cfg = config.my.programs.helix-ide;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  p = t.palette;

  # Helix theme files reference named colours from their own `palette` table.
  # Top-level `base00`-`base0F` already carry the `#` Helix expects.
  palette = lib.filterAttrs (n: _: lib.hasPrefix "base" n) p;

  generated = {
    inherit palette;

    "ui.background" = { bg = "base00"; };
    "ui.text" = { fg = "base05"; };
    "ui.text.focus" = { fg = "base05"; };
    "ui.cursor" = {
      fg = "base00";
      bg = "base05";
    };
    "ui.cursor.primary" = {
      fg = "base00";
      bg = "base0D";
    };
    "ui.cursor.match" = {
      fg = "base0A";
      bg = "base02";
    };
    "ui.linenr" = { fg = "base04"; };
    "ui.linenr.selected" = { fg = "base05"; };
    "ui.selection" = { bg = "base02"; };
    "ui.selection.primary" = { bg = "base02"; };
    "ui.statusline" = {
      fg = "base05";
      bg = "base01";
    };
    "ui.statusline.inactive" = {
      fg = "base04";
      bg = "base01";
    };
    "ui.statusline.normal" = {
      fg = "base00";
      bg = "base0D";
    };
    "ui.statusline.insert" = {
      fg = "base00";
      bg = "base0B";
    };
    "ui.statusline.select" = {
      fg = "base00";
      bg = "base0E";
    };
    "ui.popup" = {
      fg = "base05";
      bg = "base01";
    };
    "ui.window" = { fg = "base03"; };
    "ui.help" = {
      fg = "base05";
      bg = "base01";
    };
    "ui.menu" = {
      fg = "base05";
      bg = "base01";
    };
    "ui.menu.selected" = {
      fg = "base00";
      bg = "base0D";
    };
    "ui.gutter" = { bg = "base00"; };
    "ui.bufferline" = {
      fg = "base04";
      bg = "base01";
    };
    "ui.bufferline.active" = {
      fg = "base05";
      bg = "base02";
    };
    "ui.virtual.whitespace" = { fg = "base03"; };
    "ui.virtual.indent-guide" = { fg = "base03"; };
    "ui.virtual.ruler" = { bg = "base01"; };

    comment = { fg = "base03"; };
    keyword = { fg = "base0E"; };
    "keyword.control" = { fg = "base0E"; };
    function = { fg = "base0D"; };
    "function.macro" = { fg = "base0C"; };
    variable = { fg = "base05"; };
    "variable.parameter" = { fg = "base08"; };
    "variable.builtin" = { fg = "base08"; };
    constant = { fg = "base0F"; };
    "constant.numeric" = { fg = "base0F"; };
    "constant.character.escape" = { fg = "base0C"; };
    string = { fg = "base0B"; };
    "string.regexp" = { fg = "base0C"; };
    type = { fg = "base0A"; };
    "type.builtin" = { fg = "base0A"; };
    operator = { fg = "base0C"; };
    punctuation = { fg = "base05"; };
    "punctuation.bracket" = { fg = "base04"; };
    "punctuation.delimiter" = { fg = "base04"; };
    attribute = { fg = "base0D"; };
    tag = { fg = "base08"; };
    namespace = { fg = "base0A"; };
    label = { fg = "base0E"; };

    "diff.plus" = { fg = "base0B"; };
    "diff.minus" = { fg = "base08"; };
    "diff.delta" = { fg = "base09"; };

    "markup.heading" = {
      fg = "base0D";
      modifiers = [ "bold" ];
    };
    "markup.bold" = {
      fg = "base0E";
      modifiers = [ "bold" ];
    };
    "markup.italic" = {
      fg = "base09";
      modifiers = [ "italic" ];
    };
    "markup.strikethrough" = {
      fg = "base03";
      modifiers = [ "crossed_out" ];
    };
    "markup.link.url" = {
      fg = "base0D";
      modifiers = [ "underlined" ];
    };
    "markup.link.text" = { fg = "base0C"; };
    "markup.raw" = { fg = "base0B"; };
    "markup.list" = { fg = "base0C"; };

    "diagnostic.error" = {
      underline = {
        color = "base08";
        style = "curl";
      };
    };
    "diagnostic.warning" = {
      underline = {
        color = "base09";
        style = "curl";
      };
    };
    "diagnostic.info" = {
      underline = {
        color = "base0C";
        style = "curl";
      };
    };
    "diagnostic.hint" = {
      underline = {
        color = "base0B";
        style = "curl";
      };
    };
  };
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.helix-ide.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions = {
      name = lib.mkOption {
        type = lib.types.str;
        default = config.my.theming.colors.slug or "catppuccin-mocha";
        description = "Helix theme to activate. Defaults to the generated theme.";
      };

      customThemes = lib.mkOption {
        type = lib.types.attrsOf lib.types.attrs;
        default = { };
        description = "Extra Helix themes, merged over the generated one (same name wins).";
      };
    };
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    programs.helix = {
      settings.theme = lib.mkDefault t.name;
      themes = lib.recursiveUpdate { ${p.slug} = generated; } t.customThemes;
    };
  };
}
