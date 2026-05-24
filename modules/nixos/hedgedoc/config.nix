{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.hedgedoc;
  self = flake.inputs.self;
in
{
  config = mkIf cfg.enable {
    age.secrets."hedgedoc.env" = {
      file = self + /secrets/hedgedoc.env.age;
      owner = "hedgedoc";
    };

    services.hedgedoc = {
      enable = true;

      environmentFile = config.age.secrets."hedgedoc.env".path;

      settings = {
        inherit (cfg) domain port;
        protocolUseSSL = true;
        urlAddPort = false;
        allowOrigin = [ "localhost" ];
        email = false;
        allowAnonymous = cfg.allowAnonymous;
      };
    };

    services.nginx.virtualHosts.${cfg.domain} = {
      enableACME = true;
      addSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${builtins.toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}
