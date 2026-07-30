{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.squidProxy;
  htpasswdPath = "/var/cache/squid/htpasswd";
in
{
  config = mkIf cfg.enable {

    age.secrets."squid-htpasswd" = { };

    services.squid = {
      enable = true;
      proxyAddress = "100.78.102.28";
      proxyPort = cfg.proxyPort;

      extraConfig = ''
        auth_param basic program ${pkgs.squid}/libexec/basic_ncsa_auth ${htpasswdPath}
        auth_param basic realm Squid proxy — authentication required
        auth_param basic credentialsttl 8 hours

        acl authenticated proxy_auth REQUIRED
        acl tailnet src ${cfg.tailnetCidr}

        http_access allow tailnet authenticated

        ${cfg.extraConfig}
      '';
    };

    systemd.services.squid-htpasswd-gen = {
      description = "Generate Squid htpasswd file from agenix secret";
      before = [ "squid.service" ];
      requiredBy = [ "squid.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        PASSWORD="$(<${config.age.secrets."squid-htpasswd".path})"
        ${pkgs.apacheHttpd}/bin/htpasswd -cbB ${htpasswdPath} ${cfg.authUsername} "$PASSWORD"
        chown squid:squid ${htpasswdPath}
        chmod 400 ${htpasswdPath}
      '';
    };

    users.users.squid = {
      isSystemUser = true;
      group = "squid";
      home = "/var/cache/squid";
      createHome = true;
    };

    users.groups.squid = { };

  };
}
