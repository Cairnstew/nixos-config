{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.proxy;

  enabledUpstreams = lib.filterAttrs (_: u: u.enable) cfg.upstreams;

  # Build a Caddy handle (or handle_path) block for an upstream
  handleBlock = name: upstream:
    let
      directive = if upstream.stripPrefix then "handle_path" else "handle";
      path = "${upstream.path}*";
    in
    ''
      ${directive} ${path} {
        reverse_proxy ${upstream.host}:${toString upstream.port}
        ${upstream.extraConfig}
      }
    '';

  # Dashboard HTML page
  dashboardHtml = pkgs.writeText "dashboard.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${cfg.dashboard.title}</title>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          background: #0f0f14;
          color: #e0e0e0;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          padding: 3rem 1rem;
        }
        .container { max-width: 800px; width: 100%; }
        h1 { font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }
        p.subtitle { color: #888; margin-bottom: 2rem; font-size: 0.95rem; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 1rem; }
        a.card {
          display: block;
          background: #1a1a24;
          border: 1px solid #2a2a38;
          border-radius: 10px;
          padding: 1.25rem;
          text-decoration: none;
          color: inherit;
          transition: border-color 0.2s, transform 0.15s;
        }
        a.card:hover { border-color: #4a4a6a; transform: translateY(-2px); }
        a.card h2 { font-size: 1.1rem; font-weight: 500; margin-bottom: 0.25rem; }
        a.card .path { font-family: "SF Mono", monospace; font-size: 0.8rem; color: #5a8aff; }
        a.card .desc { font-size: 0.8rem; color: #777; margin-top: 0.4rem; }
        .footer { margin-top: 3rem; font-size: 0.75rem; color: #555; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>${cfg.dashboard.title}</h1>
        <p class="subtitle">${cfg.dashboard.description}</p>
        <div class="grid">
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: u: let displayName = if u.displayName != null then u.displayName else name; in ''
          <a href="${u.path}" class="card">
            <h2>${displayName}</h2>
            <div class="path">${u.path}</div>
          </a>
          '') enabledUpstreams)}
        </div>
        <p class="footer"><script>document.write(window.location.host)</script></p>
      </div>
    </body>
    </html>
  '';

  dashboardDir = pkgs.runCommand "dashboard" { } ''
    mkdir -p $out
    cp ${dashboardHtml} $out/index.html
  '';

  # Use :port as the site address (catch-all for any Host header — required
  # because Tailscale serve preserves the original Host when forwarding).
  # The bind directive restricts which interfaces Caddy actually listens on.
  # http:// prefix disables automatic TLS — Tailscale handles HTTPS at the edge.

  # Build bind directive from listenAddresses
  bindList = lib.concatStringsSep " " cfg.listenAddresses;

  # Generate Caddyfile
  caddyfile = pkgs.writeText "Caddyfile" ''
    http://:${toString cfg.port} {
      bind ${bindList}
      ${lib.optionalString cfg.dashboard.enable ''
      handle /index.html {
        root * ${dashboardDir}
        file_server
      }
      handle / {
        root * ${dashboardDir}
        file_server
      }
      ''}

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList handleBlock enabledUpstreams)}

      ${lib.concatStringsSep "\n" (lib.concatMap (u: u.extraLocations) (builtins.attrValues enabledUpstreams))}

      handle {
        respond "Not Found" 404
      }

      ${cfg.extraConfig}
    }
  '';

  # Tailscale serve URL (uses the first listen address)
  tailscaleUrl = "http://${builtins.elemAt cfg.listenAddresses 0}:${toString cfg.port}";
in
{
  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;
      configFile = caddyfile;
    };

    systemd.services.tailscale-serve = lib.mkIf cfg.tailscaleServe.enable {
      description = "Tailscale Serve — route :${toString cfg.tailscaleServe.httpsPort} to Caddy reverse proxy";
      after = [ "tailscaled.service" "caddy.service" ];
      wants = [ "caddy.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https ${toString cfg.tailscaleServe.httpsPort} ${tailscaleUrl}";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https ${toString cfg.tailscaleServe.httpsPort} off";
      };
    };
  };
}
