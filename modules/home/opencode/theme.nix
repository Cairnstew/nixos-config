# OpenCode theming — the repo palette as an OpenCode `themes` entry.
#
# Moved here from modules/nixos/homeManager/mcp-wrappers.nix (the NixOS
# home-manager side-car), so the module that owns opencode also owns its
# theming. `my.programs.opencode.themes` still feeds `programs.opencode.themes`
# (modules/home/opencode/config.nix), and user-supplied themes of the same name
# win (`mkDefault`).
{ config, lib, ... }:

let
  cfg = config.my.programs.opencode;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  p = t.palette;

  # Opencode theme derived from the shared palette (my.theming.scheme).
  #
  # The `defs` block is the raw base16 palette; the `theme` block then maps
  # opencode's own role names onto those slots by string reference, so the role
  # names opencode requires are preserved while the colours come from the one
  # resolved palette. The theme is keyed by the active scheme's slug, so it
  # follows a scheme switch instead of always claiming to be Catppuccin Mocha.
  # Flake-level option renamed to `my.theming` for namespacing (T1).
  # The generated V1 `defs`+`theme` shape. OpenCode 2 reads cli.json and
  # ignores tui.json themes; the stylix target still owns the CLI theme there
  # (modules/nixos/stylix/config.nix keeps `cli.theme.name = "stylix"`), so this
  # is the TUI/OpenCode-1 view of the same palette.
  generated = {
    "${p.slug}" = {
      defs = {
        inherit (p) base00 base01 base02 base03 base04 base05 base06 base07
          base08 base09 base0A base0B base0C base0D base0E base0F
          cursor;
      };
      theme = {
        primary = "base0D";
        secondary = "base0C";
        accent = "base0E";
        error = "base08";
        warning = "base09";
        success = "base0B";
        info = "base0D";
        text = "base05";
        textMuted = "base04";
        background = "base00";
        backgroundPanel = "base01";
        backgroundElement = "base02";
        border = "base03";
        borderActive = "base0D";
        borderSubtle = "base02";
        diffAdded = "base0B";
        diffRemoved = "base08";
        diffContext = "base03";
        diffHunkHeader = "base04";
        diffHighlightAdded = "base0B";
        diffHighlightRemoved = "base08";
        diffAddedBg = "base02";
        diffRemovedBg = "base02";
        diffContextBg = "base01";
        diffLineNumber = "base03";
        diffAddedLineNumberBg = "base01";
        diffRemovedLineNumberBg = "base01";
        markdownText = "base05";
        markdownHeading = "base0D";
        markdownLink = "base0C";
        markdownLinkText = "base0D";
        markdownCode = "base0B";
        markdownBlockQuote = "base03";
        markdownEmph = "base09";
        markdownStrong = "base0A";
        markdownHorizontalRule = "base03";
        markdownListItem = "base0D";
        markdownListEnumeration = "base0C";
        markdownImage = "base0C";
        markdownImageText = "base0E";
        markdownCodeBlock = "base05";
        syntaxComment = "base03";
        syntaxKeyword = "base0E";
        syntaxFunction = "base0D";
        syntaxVariable = "base0C";
        syntaxString = "base0B";
        syntaxNumber = "base0F";
        syntaxType = "base0A";
        syntaxOperator = "base0C";
        syntaxPunctuation = "base05";
      };
    };
  };
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.opencode.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    # `mkDefault`: a user-supplied theme with the same slug wins.
    my.programs.opencode.themes = lib.mkDefault generated;
  };
}
