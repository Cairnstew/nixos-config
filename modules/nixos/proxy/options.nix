{ lib, ... }:
let
  upstreamType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable this upstream in the reverse proxy.";
      };

      displayName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Human-readable name shown on the dashboard card.
          Falls back to the attribute key if not set.
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Backend host address.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "Backend port.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        description = ''
          URL path prefix for this service (e.g., /risuai/).
          Used as a `handle_path` matcher in the Caddyfile — the prefix is
          stripped before proxying unless stripPrefix is set to false.
        '';
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to strip the path prefix when proxying.
          True:  uses Caddy `handle_path` — strips /prefix before sending
                 to backend (backend sees root-relative paths).
          False: uses Caddy `handle` — full URI including the prefix is
                 passed through to the backend unmodified.
        '';
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra Caddyfile lines inside the handle/reverse_proxy block.";
      };

      extraLocations = lib.mkOption {
        type = lib.types.listOf lib.types.lines;
        default = [ ];
        description = ''
          Additional Caddy `handle` blocks outside the main path.
          Used by SPAs at sub-paths that also need to serve assets/API
          from root-relative paths (e.g., /assets/, /api/).
          Each entry is a raw Caddyfile block — typically `handle /path/* { ... }`.
          Order matters: more specific paths first.
        '';
      };

      trustProxy = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "express" "uvicorn" ]);
        default = null;
        description = ''
          Backend proxy-trust mechanism for this service. When set, the service
          module should inject the corresponding env var/flag so the backend
          trusts the `X-Forwarded-For` header set by Caddy's reverse proxy.

          Supported mechanisms:
          - `"express"`: Express.js apps — set TRUST_PROXY=1
            (e.g. RisuAI, SillyTavern)
          - `"uvicorn"`: uvicorn/FastAPI apps that default to only trusting
            127.0.0.1 — set FORWARDED_ALLOW_IPS=* (e.g. Letta).
            Not needed for Open WebUI — its Docker start.sh already passes
            `--forwarded-allow-ips "*"` by default.
        '';
      };
    };
  };
in
{
  options.my.services.proxy = {
    enable = lib.mkEnableOption "unified Caddy reverse proxy with tailscale-serve";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port for Caddy to listen on.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses for Caddy to listen on.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra raw Caddyfile lines appended to the site block.";
    };

    dashboard = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the service dashboard at root /.";
      };

      title = lib.mkOption {
        type = lib.types.str;
        default = "Server Dashboard";
        description = "Title for the dashboard page.";
      };

      description = lib.mkOption {
        type = lib.types.lines;
        default = "Browse available services";
        description = "Short description shown below the title.";
      };
    };

    systemMetrics = {
      enable = lib.mkEnableOption "system metrics collection and dashboard display";

      refreshInterval = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Collection interval in seconds.";
      };
    };

    tailscaleServe = {
      enable = lib.mkEnableOption "auto-configure tailscale serve to proxy :443 → Caddy";

      httpsPort = lib.mkOption {
        type = lib.types.port;
        default = 443;
        description = "HTTPS port for tailscale serve to listen on.";
      };
    };

    upstreams = lib.mkOption {
      type = lib.types.attrsOf upstreamType;
      default = { };
      description = ''
        Web services to proxy. Modules auto-register themselves here.
        Override individual fields per-host to customize paths.
      '';
    };
  };
}
