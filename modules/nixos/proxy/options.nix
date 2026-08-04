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

    extraCaddyEnvironmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Additional EnvironmentFiles for the caddy service. Consumed by the
        dashboard's opencode API handles (<option>apiAuthEnv</option>) to inject
        credentials server-side without baking secrets into the Caddyfile.
      '';
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

      opencode = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Unique instance name (repo name).";
            };

            label = lib.mkOption {
              type = lib.types.str;
              description = "Display label on the dashboard card.";
            };

            port = lib.mkOption {
              type = lib.types.port;
              description = "Backend port of the opencode web instance.";
            };

            host = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1";
              description = "Backend host of the opencode web instance.";
            };

            href = lib.mkOption {
              type = lib.types.str;
              description = "URL that opens the instance's web UI.";
            };

            servePort = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = ''
                Tailnet HTTPS port for the instance (tailscale serve). When set,
                the dashboard links to <literal>https://&lt;current-host&gt;:&lt;servePort&gt;/</literal>
                instead of <literal>href</literal> when viewed via the tailnet
                hostname.
              '';
            };

            apiPath = lib.mkOption {
              type = lib.types.str;
              description = "Same-origin path prefix proxied to the instance (e.g. /opencode-api/nix-config).";
            };

            apiAuthEnv = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Name of a Caddyfile env var (set via an EnvironmentFile on the
                caddy service) whose value is the <literal>Authorization</literal>
                header to inject when proxying the API handle. Used when the
                backend requires basic auth so the dashboard's session fetch
                works without the browser sending credentials.
              '';
            };

            directory = lib.mkOption {
              type = lib.types.str;
              description = "Project directory served by the instance — base64-encoded at runtime for session deep-links.";
            };
          };
        });
        default = [ ];
        description = ''
          OpenCode web instances rendered in the dashboard's OpenCode section
          with a live session list. Populated by the opencode-web module
          (<option>my.services.opencodeWeb</option>).
        '';
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
