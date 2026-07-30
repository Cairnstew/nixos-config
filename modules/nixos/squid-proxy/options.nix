{ lib, ... }:
let
  inherit (lib) types mkOption mkEnableOption;
in
{
  options.my.services.squidProxy = {
    enable = mkEnableOption "Squid forward proxy for browser egress";

    proxyPort = mkOption {
      type = types.port;
      default = 3128;
      description = "TCP port on which Squid will listen.";
    };

    htpasswdFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to an htpasswd file for proxy authentication.
        Use config.age.secrets."squid-htpasswd".path.
      '';
    };

    tailnetCidr = mkOption {
      type = types.str;
      default = "100.64.0.0/10";
      description = "Tailscale CGNAT CIDR to restrict proxy access to.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra lines appended to the Squid ACL config (before final deny-all).";
    };
  };
}
