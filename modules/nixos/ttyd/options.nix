{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.ttyd = {
    enable = mkEnableOption "ttyd web terminal (browser-based emergency SSH console)";

    port = mkOption {
      type = types.port;
      default = 7681;
      description = "Port to listen on.";
    };

    address = mkOption {
      type = types.nullOr types.str;
      default = "127.0.0.1";
      description = ''
        IP address or interface name to bind. Bind to a fallback mesh IP
        (e.g. a ZeroTier address) to make the console independent of Tailscale.
        Default 127.0.0.1 — expose via the reverse proxy instead.
      '';
      example = "192.168.191.54";
    };

    username = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "HTTP basic-auth username (must be set with passwordFile).";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the HTTP basic-auth password (use an agenix secret path).";
    };

    writeable = mkOption {
      type = types.bool;
      default = true;
      description = "Allow clients to write to the terminal (required to be explicitly set by the NixOS module).";
    };

    entrypoint = mkOption {
      type = types.listOf types.str;
      default = [ "/run/current-system/sw/bin/bash" ];
      description = "Command ttyd runs (default: a root shell — pair with basic auth).";
    };

    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Unix user ttyd runs as (null = root).";
    };

    maxClients = mkOption {
      type = types.int;
      default = 2;
      description = "Maximum concurrent clients.";
    };

    checkOrigin = mkOption {
      type = types.bool;
      default = true;
      description = "Reject websocket connections from a different origin.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the listen port in the firewall (needed when binding outside trusted interfaces).";
    };

    proxyUpstream = mkOption {
      type = types.bool;
      default = true;
      description = "Register as a reverse-proxy upstream for tailnet HTTPS access.";
    };
  };
}
