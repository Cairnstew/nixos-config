# =============================================================================
# lib/theme.nix — the per-application theming toolkit
# =============================================================================
# The layer between the resolved palette (`lib/theming.nix`) and the modules.
# It exists so 19+ applications do not each re-implement the same four things:
#
#   1. the standard `theme` option shape       → mkAppTheme
#   2. per-app colour overrides that re-derive → recolor (theming.recolor)
#   3. CSS custom properties from roles        → cssVars
#   4. the 16 ANSI colours / xterm theme       → ansi16, ansi16Values, xterm
#
# What it deliberately does NOT do is serialise app-specific formats (TOML,
# KDL, YAML, JSON): that mapping is the specialised part and belongs in the
# module's own `theme.nix`. See docs/decisions/2026-11-13-theme-nix.md.
#
# Pure (`{ lib }:` only): no flake, no module system, so it is unit-testable
# and usable from `flake.lib.theme`.
{ lib }:

let
  theming = import ./theming.nix { inherit lib; };
  inherit (theming) color;

  # ── Option shape ────────────────────────────────────────────────────────
  #
  # Every UI module declares exactly one theme option with this:
  #
  #   options.my.programs.<app>.theme = themeLib.mkAppTheme {
  #     base = config.my.theming.colors;
  #   };
  #
  # `extraOptions` adds application-specific knobs (opacity, wallpaper,
  # extraCss, …) without inventing a second option shape.
  # `extraOptions` may be an attrset, or a function `{ config }: attrs` when an
  # option default needs the already-resolved palette (e.g. vscode's generated
  # `settings` attrset).
  mkAppTheme =
    { base
    , extraOptions ? { }
    , defaultEnable ? true
    ,
    }:
    lib.mkOption {
      type = lib.types.submodule (
        { config, ... }:
        {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = defaultEnable;
              description = ''
                Apply this application's theme when the application itself is
                enabled. Set to false to keep the app enabled but unthemed (for
                example when a plugin or a system theme owns its appearance).
              '';
            };

            overrides = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              example = lib.literalExpression ''
                {
                  accent = "#ff0055";   # role override: nothing else moves
                  base00 = "#000000";   # slot override: every dependent role follows
                }
              '';
              description = ''
                Per-application colour overrides, applied on top of the global
                palette with the same two-phase rules as
                `my.theming.overrides` (base16 slots first, roles last).
              '';
            };

            palette = lib.mkOption {
              type = lib.types.attrs;
              readOnly = true;
              default = theming.recolor {
                palette = base;
                inherit (config) overrides;
              };
              defaultText = lib.literalExpression "the global palette with this app's overrides applied";
              description = ''
                The resolved palette for this application: `my.theming.colors`
                plus `overrides`, re-derived. This is what `theme.nix` reads;
                introspectable with `nix eval`.
              '';
            };
          } // (
            if builtins.isFunction extraOptions then
              extraOptions { inherit config; }
            else
              extraOptions
          );
        }
      );
      default = { };
      description = ''
        Theming for this application: whether to apply it, per-app colour
        overrides, and the resulting palette. See
        `docs/decisions/2026-11-13-theme-nix.md`.
      '';
    };

  # ── ANSI / terminal ────────────────────────────────────────────────────

  # Index order is the ANSI/xterm convention: 0-7 normal, 8-15 bright.
  ansiNames = [
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

  ansi16Values = palette: map (n: palette.terminal.${n}) ansiNames;

  # Ghostty/foot style: [ "0=#1e1e2e" "1=#f38ba8" … ].
  ansi16 =
    palette:
    lib.imap0 (i: value: "${builtins.toString i}=${value}") (ansi16Values palette);

  # xterm.js ITheme, e.g. `services.ttyd.clientOptions.theme = toJSON (xterm p)`.
  xterm =
    palette:
    {
      background = palette.background;
      foreground = palette.foreground;
      cursor = palette.cursor;
      cursorAccent = palette.background;
      selectionBackground = palette.selection;
      selectionForeground = palette.selectionText;
    }
    // lib.genAttrs ansiNames (n: palette.terminal.${n});

  # ── CSS ────────────────────────────────────────────────────────────────

  # The roles worth exposing as CSS variables. Kept explicit so a new role is
  # an intentional addition to every stylesheet, not an accidental one.
  cssRoles = [
    "background"
    "surface"
    "backgroundAlt"
    "backgroundElement"
    "foreground"
    "foregroundMuted"
    "border"
    "borderSubtle"
    "accent"
    "accentAlt"
    "success"
    "warning"
    "error"
    "info"
    "cursor"
    "selection"
    "selectionText"
  ];

  # camelCase → kebab-case, without regex (Nix has none): `backgroundAlt`
  # becomes `background-alt`, so `--theme-background-alt` reads naturally in
  # generated CSS.
  toKebab =
    s:
    let
      chars = lib.stringToCharacters s;
      step =
        acc: c:
        if c == lib.toLower c then
          acc + c
        else
          "${acc}-${lib.toLower c}";
    in
    lib.removePrefix "-" (lib.foldl' step "" chars);

  # A `:root { --<prefix>-<role>: …; }` block. `extra` is merged last, for
  # app-specific variables (e.g. `{ "font-family" = "Inter"; }`).
  cssVars =
    { palette
    , prefix ? "theme"
    , roles ? cssRoles
    , extra ? { }
    ,
    }:
    let
      present = builtins.filter (n: palette ? ${n}) roles;
      roleLine = n: "  --${prefix}-${toKebab n}: ${palette.${n}};";
      extraLine = n: "  --${prefix}-${toKebab n}: ${extra.${n}};";
      lines = map roleLine present ++ map extraLine (builtins.attrNames extra);
    in
    if lines == [ ] then
      ""
    else
      ":root {\n" + lib.concatStringsSep "\n" lines + "\n}";
in
{
  inherit
    color
    mkAppTheme
    ansiNames
    ansi16
    ansi16Values
    xterm
    cssRoles
    cssVars
    toKebab
    ;
  recolor = theming.recolor;
}
