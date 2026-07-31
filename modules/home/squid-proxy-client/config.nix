{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs.squidProxyClient;
  pwdFile =
    if cfg.proxyPasswordFile != null then cfg.proxyPasswordFile
    else "/run/agenix/squid-htpasswd";
  proxyUrl = "http://${cfg.proxyUsername}:@@PASSWORD@@@${cfg.serverAddress}:${toString cfg.proxyPort}";
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

    xdg.configFile."qutebrowser-proxy/config.py".text = ''
      import os

      c.content.proxy = "${proxyUrl}"

      pwd_file = "${pwdFile}"
      if os.path.exists(pwd_file):
          with open(pwd_file) as f:
              password = f.read().strip()
          c.content.proxy = "http://${cfg.proxyUsername}:" + password + "@${cfg.serverAddress}:${toString cfg.proxyPort}"
    '';

    home.shellAliases."proxy-browser-persist" = ''
      qutebrowser --basedir ~/.config/qutebrowser-proxy
    '';

  };
}
