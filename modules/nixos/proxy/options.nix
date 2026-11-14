{ lib, flake, ... }:
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

      # Basic auth for the dashboard page and its /api/metrics endpoint only.
      # Service paths registered as upstreams are NOT covered — they keep
      # whatever auth the backend provides. The password lives in agenix and
      # is hashed at boot by a systemd oneshot, so the plaintext never enters
      # the Nix store (only the bcrypt hash reaches the Caddy EnvironmentFile).
      auth = {
        enable = lib.mkEnableOption "HTTP basic auth on the dashboard page and metrics API";

        username = lib.mkOption {
          type = lib.types.str;
          default = flake.config.me.username;
          description = "Basic-auth username (defaults to the primary user).";
        };

        passwordSecret = lib.mkOption {
          type = lib.types.str;
          default = "dashboard-basic-auth";
          description = ''
            agenix secret holding the dashboard password in plaintext. The
            secret must exist on any host with auth enabled; a
            <literal>nixos-rebuild</literal> assertion enforces it.
          '';
        };
      };

      # Cards for services that are NOT behind this proxy: they have their own
      # port and are usually published on the tailnet by a separate
      # `tailscale serve` rule. `servePort` mirrors the opencode section below —
      # when the dashboard is viewed from a non-local host the card links to
      # https://<current-host>:<servePort>/, so a single card works both from
      # the box and from another tailnet machine.
      links = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            label = lib.mkOption {
              type = lib.types.str;
              description = "Card title.";
            };

            description = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Short line shown under the title.";
            };

            href = lib.mkOption {
              type = lib.types.str;
              description = ''
                Fallback URL, used when the dashboard is viewed from localhost
                or when <option>servePort</option> is null.
              '';
            };

            servePort = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = ''
                Tailnet HTTPS port for this service. When set, non-local viewers
                link to <literal>https://&lt;current-host&gt;:&lt;servePort&gt;/</literal>.
              '';
            };
          };
        });
        default = [ ];
        description = ''
          Extra dashboard cards for services served on their own port instead of
          a path under this proxy — for example a frontend that cannot live
          under a path prefix (SillyTavern with accounts, the Breeze TTS UI).
          Rendered in a "Direct" section below the proxied services.
        '';
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

      # Minecraft server management section (populated by the minecraft-server
      # module). Mirrors the opencode section: a small management API proxied by
      # Caddy, rendered as live server status cards with start/stop/restart
      # buttons.
      minecraft = {
        enable = lib.mkEnableOption "Minecraft server management section on the dashboard";

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Backend host of the minecraft management API.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 7799;
          description = "Backend port of the minecraft management API.";
        };

        apiPath = lib.mkOption {
          type = lib.types.str;
          default = "/api/minecraft";
          description = "Same-origin path prefix proxied to the minecraft management API.";
        };
      };

      # Project Zomboid server management section (populated by the
      # projectzomboid-server module, which owns the API behind it). Mirrors the
      # minecraft section: a small management API proxied by Caddy, rendered as
      # live server cards with start/stop/restart buttons and a link to each
      # server's ttyd console.
      #
      # The console itself is the upstream module's `web.enable`; this section
      # only surfaces state and links to it, so enabling the section without the
      # console yields cards with no Console link.
      projectzomboid = {
        enable = lib.mkEnableOption "Project Zomboid server management section on the dashboard";

        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Backend host of the Project Zomboid management API.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 7798;
          description = "Backend port of the Project Zomboid management API.";
        };

        apiPath = lib.mkOption {
          type = lib.types.str;
          default = "/api/projectzomboid";
          description = "Same-origin path prefix proxied to the Project Zomboid management API.";
        };

        consoleBase = lib.mkOption {
          type = lib.types.str;
          default = "/pz";
          description = ''
            URL prefix for the per-server ttyd consoles, matching the upstream
            module's <literal>webConsoleUpstreams</literal> paths
            (<literal>/pz/&lt;name&gt;/</literal>). The API builds each card's
            console link from this.
          '';
        };
      };
    };

    systemMetrics = {
      enable = lib.mkEnableOption "system metrics collection and dashboard display";

      refreshInterval = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Collection interval in seconds.";
      };

      # OpenCode Go subscription usage, merged into /api/metrics/metrics.json
      # as `opencodeGo`. Point this at the JSON snapshot written by the
      # opencode-go-usage refresher
      # (~/.cache/opencode/go-usage.json; enable with
      # my.programs.opencode.opencode-go.usage.enable).
      opencodeGo = {
        usageJsonFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/home/seanc/.cache/opencode/go-usage.json";
          description = ''
            Path to an OpenCode Go usage snapshot (as returned by
            https://opencode.ai/zen/go/v1/usage) to merge into the
            dashboard's metrics.json and render as usage bars.
          '';
        };
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
