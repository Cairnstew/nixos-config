# Shared qutebrowser config.py fragment.
#
# Imported by modules/home/qutebrowser/config.nix (default profile,
# ~/.config/qutebrowser/config.py) and modules/home/squid-proxy-client/config.nix
# (proxy profile, ~/.config/qutebrowser-proxy/config/config.py) so both profiles
# get the same 1Password binding and Google sign-in fix.
{ lib
, onePassword ? false
, keybinding ? "<Ctrl-Shift-p>"
, googleUserAgent ? null
}:
let
  inherit (lib) concatStringsSep optional;
  lines = [
    "# Shared settings — edit modules/home/qutebrowser/lib.nix, not this file."
  ]
  ++ optional onePassword ''
    # 1Password: qutebrowser has no extension API, so the browser extension
    # cannot be installed. This userscript is the native equivalent and talks
    # to the 1Password CLI (`op`) instead.
    config.bind("${keybinding}", "spawn --userscript qute-1pass.py")

    # `:1pass` / `:1pass <title-or-url-fragment>`; aliases append extra
    # arguments, so the query reaches the userscript's argv.
    c.aliases["1pass"] = "spawn --userscript qute-1pass.py"
  ''
  ++ optional (googleUserAgent != null) ''
    # Google refuses OAuth / account sign-in from QtWebEngine-based browsers
    # (qutebrowser issues #5182 and #8492). qutebrowser's built-in `ua-google`
    # quirk rewrites the User-Agent header for accounts.google.com but has had
    # to be bumped repeatedly; pin it explicitly so it cannot go stale.
    _google_ua = "${googleUserAgent}"
    for _pattern in ["https://accounts.google.com/*", "https://accounts.youtube.com/*"]:
        config.set("content.headers.user_agent", _google_ua, _pattern)
  '';
in
concatStringsSep "\n" lines + "\n"
