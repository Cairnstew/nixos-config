{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.squidProxyClient;
  pwdFile =
    if cfg.proxyPasswordFile != null then cfg.proxyPasswordFile
    else "/run/agenix/squid-htpasswd";
in
{
  config = mkIf cfg.enable {

    home.packages = [ pkgs.qutebrowser ];

    home.shellAliases = {
      proxy-browser = ''
        qutebrowser --basedir /tmp/proxy-session \
          ':set content.proxy http://${cfg.proxyUsername}:'"$(<${pwdFile})"'@${cfg.serverAddress}:${toString cfg.proxyPort}'
      '';
    };

    # qutebrowser looks for config.py at `<basedir>/config/config.py` (with
    # --basedir, standarddir.config() is `<basedir>/config`), NOT at the
    # basedir root — putting it at the root silently does nothing.
    # load_autoconfig() must come first: it silences qutebrowser's
    # "autoconfig loading not specified" error and loads GUI-set settings
    # before we pin the proxy on top of them.
    xdg.configFile."qutebrowser-proxy/config/config.py".text = ''
      import os

      config.load_autoconfig()

      pwd_file = "${pwdFile}"
      if os.path.exists(pwd_file):
          with open(pwd_file) as f:
              password = f.read().strip()
          c.content.proxy = "http://${cfg.proxyUsername}:" + password + "@${cfg.serverAddress}:${toString cfg.proxyPort}"
    '';

    home.shellAliases."proxy-browser-persist" = ''
      qutebrowser --basedir ~/.config/qutebrowser-proxy
    '';

    # App-menu launcher for the persistent proxy session (same basedir as the
    # `proxy-browser-persist` alias). The password is read at startup from the
    # agenix secret by the generated config.py above — never baked into the
    # .desktop file. `--basedir` is absolute because .desktop Exec lines do not
    # expand `~` or `$HOME`.
    xdg.desktopEntries."qutebrowser-proxy" = {
      name = "Proxy Browser";
      genericName = "Web Browser";
      comment = "qutebrowser routed through the Squid forward proxy on ${cfg.serverAddress}";
      exec = "${lib.getExe pkgs.qutebrowser} --basedir ${config.home.homeDirectory}/.config/qutebrowser-proxy --desktop-file-name qutebrowser-proxy --untrusted-args %u";
      icon = "qutebrowser";
      categories = [ "Network" "WebBrowser" ];
      mimeType = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
      terminal = false;
      startupNotify = true;
      settings = {
        StartupWMClass = "qutebrowser";
      };
    };

  };
}
