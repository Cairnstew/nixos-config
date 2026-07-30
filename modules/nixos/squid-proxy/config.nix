{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.squidProxy;
  hasAuth = cfg.htpasswdFile != null;
in
{
  config = mkIf cfg.enable {

    services.squid = {
      enable = true;
      proxyAddress = "100.78.102.28";
      proxyPort = cfg.proxyPort;

      extraConfig = ''
        ${lib.optionalString hasAuth ''
          auth_param basic program ${pkgs.squid}/libexec/basic_ncsa_auth ${cfg.htpasswdFile}
          auth_param basic realm Squid proxy — authentication required
          auth_param basic credentialsttl 8 hours

          acl authenticated proxy_auth REQUIRED
        ''}

        acl tailnet src ${cfg.tailnetCidr}

        ${lib.optionalString hasAuth ''
          http_access allow tailnet authenticated
        ''}
        ${lib.optionalString (!hasAuth) ''
          http_access allow tailnet
        ''}
        ${cfg.extraConfig}
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
