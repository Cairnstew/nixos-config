{ config, lib, ... }:
let
  inherit (lib) mkIf hasPrefix;
  cfg = config.my.programs.qutebrowser;
in
{
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.onePassword.enable || hasPrefix "<" cfg.onePassword.keybinding;
        message = "my.programs.qutebrowser.onePassword.keybinding must be a key binding like \"<Ctrl-Shift-p>\".";
      }
      {
        assertion = !cfg.googleSignInFix.enable || cfg.googleSignInFix.userAgent != "";
        message = "my.programs.qutebrowser.googleSignInFix.userAgent must not be empty.";
      }
      {
        assertion = !cfg.theme.enable || (cfg.theme.palette ? background && cfg.theme.palette ? accent);
        message = "qutebrowser theme: the resolved palette is missing background/accent.";
      }
      {
        assertion =
          !cfg.theme.enable
          || lib.hasInfix "c.colors.statusbar.normal.bg"
            config.xdg.configFile."qutebrowser/theme.py".text;
        message = "qutebrowser theme: theme.py does not contain the generated colours.";
      }
    ];
  };
}
