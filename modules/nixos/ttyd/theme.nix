# ttyd theming — the browser terminal's xterm.js palette.
#
# ttyd passes `--client-option key=value` through to xterm.js; the `theme` key
# takes an ITheme object as JSON. `themeLib.xterm` produces exactly that shape
# from the shared palette, so the console in a browser matches the local
# terminal (which ghostty's generated theme also follows).
{ config, lib, ... }:

let
  cfg = config.my.services.ttyd;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.services.ttyd.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        clientOptions = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          readOnly = true;
          default = if config.enable then { theme = builtins.toJSON (themeLib.xterm config.palette); } else { };
          defaultText = lib.literalExpression "xterm.js theme from my.theming.colors";
          description = "ttyd `--client-option` values contributed by the theme.";
        };
      };
  };

  config = lib.mkIf (cfg.enable && t.enable) {
    services.ttyd.clientOptions = t.clientOptions;
  };
}
