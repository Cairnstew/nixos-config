{ lib, ... }:
let
  inherit (lib) types mkOption mkEnableOption;
in
{
  options.my.programs.qutebrowser = {
    enable = mkEnableOption "qutebrowser, with a 1Password CLI userscript and a Google sign-in User-Agent fix";

    onePassword = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Install the `qute-1pass.py` userscript and bind it to
          {option}`onePassword.keybinding`.

          qutebrowser has no browser-extension API (QtWebEngine cannot load
          Chrome/Firefox extensions), so this userscript stands in for the
          1Password browser extension: it queries the 1Password CLI (`op`) and
          fills the current page's login form.
        '';
      };

      keybinding = mkOption {
        type = types.str;
        default = "<Ctrl-Shift-p>";
        description = "Key binding for the 1Password fill userscript.";
        example = "<Alt-Shift-p>";
      };
    };

    googleSignInFix = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Pin a Firefox User-Agent for the Google identity endpoints
          (`accounts.google.com`, `accounts.youtube.com`).

          Google blocks OAuth and account sign-in from QtWebEngine-based
          browsers (qutebrowser issues #5182 and #8492). qutebrowser ships a
          `ua-google` site-specific quirk for this, but Google periodically
          starts refusing the pinned version, so it is overridden here.
        '';
      };

      userAgent = mkOption {
        type = types.str;
        default = "Mozilla/5.0 ({os_info}; rv:135.0) Gecko/20100101 Firefox/135.0";
        description = ''
          User-Agent sent to the Google identity endpoints. `{os_info}` is
          expanded by qutebrowser. Only matched patterns are affected; other
          sites keep the regular Chromium User-Agent.
        '';
      };
    };
  };
}
