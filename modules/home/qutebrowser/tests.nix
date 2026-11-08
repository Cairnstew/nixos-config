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
    ];
  };
}
