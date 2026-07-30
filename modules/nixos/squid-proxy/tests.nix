{ config, lib, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.squidProxy;
in
{
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.age.secrets ? "squid-htpasswd";
        message = ''
          my.services.squidProxy: agenix secret "squid-htpasswd" is required.
          Create the secret with: agenix-manager new
        '';
      }
    ];
  };
}
