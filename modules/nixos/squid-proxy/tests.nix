{ config, lib, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.squidProxy;
in
{
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.htpasswdFile != null;
        message = ''
          my.services.squidProxy: htpasswdFile must be set (e.g. config.age.secrets."squid-htpasswd".path).
          Create the secret with: agenix-manager new
        '';
      }
    ];
  };
}
