{ lib, ... }:
let
  inherit (lib) types mkOption mkEnableOption;
in
{
  options.my.programs.squidProxyClient = {
    enable = mkEnableOption "qutebrowser configured for Squid forward proxy";

    serverAddress = mkOption {
      type = types.str;
      default = "100.78.102.28";
      description = "Tailscale IP of the Squid proxy server.";
    };

    proxyPort = mkOption {
      type = types.port;
      default = 3128;
      description = "Proxy port on the server.";
    };

    proxyUsername = mkOption {
      type = types.str;
      default = "seanc";
      description = "Proxy auth username.";
    };

    proxyPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing the proxy password (plaintext).
        Use config.age.secrets."squid-htpasswd".path if available on this host.
      '';
    };
  };
}
