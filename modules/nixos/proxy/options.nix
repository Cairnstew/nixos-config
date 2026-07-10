{ lib, ... }:
let
  upstreamType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable this upstream in the reverse proxy.";
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
          Must end with a trailing slash so nginx can match the location.
        '';
      };

      stripPrefix = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to strip the path prefix when proxying (add trailing slash
          to proxy_pass). Set to false for subpath-aware backends that inject
          their own <base href> and serve all content under the path — the
          full URI including the prefix is passed through unmodified.
        '';
      };

      websocket = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Add WebSocket upgrade headers (Upgrade, Connection).";
      };

      htmlBase = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          If set, injects <base href="$htmlBase"> via subs_filter so SPAs
          served at a sub-path resolve assets correctly (e.g., /risuai/).
        '';
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra nginx location config lines (proxy_buffering, client_max_body_size, etc.).";
      };

      extraLocations = lib.mkOption {
        type = lib.types.listOf lib.types.lines;
        default = [ ];
        description = ''
          Additional nginx location blocks outside the main path.
          Used by SPAs at sub-paths that also need to serve assets/API
          from root-relative paths (e.g., /assets/, /api/).
        '';
      };
    };
  };
in
{
  options.my.services.proxy = {
    enable = lib.mkEnableOption "unified nginx reverse proxy with tailscale-serve";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port for nginx to listen on.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses for nginx to listen on.";
    };

    extraNginxConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra raw nginx config lines for the server block.";
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

    tailscaleServe = {
      enable = lib.mkEnableOption "auto-configure tailscale serve to proxy :443 → nginx";

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
