{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.proxy;

  enabledUpstreams = lib.filterAttrs (_: u: u.enable) cfg.upstreams;

  # Build a single nginx location block for an upstream
  locationBlock = name: upstream:
    let
      proxyPassUrl =
        if upstream.stripPrefix
        then "http://${upstream.host}:${toString upstream.port}/"
        else "http://${upstream.host}:${toString upstream.port}";
    in
    ''
      location ${upstream.path} {
        proxy_pass ${proxyPassUrl};
        proxy_http_version 1.1;
        ${lib.optionalString upstream.websocket ''
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        ''}
        ${lib.optionalString (upstream.htmlBase != null) ''
        subs_filter '<head(?:\\s[^>]*)?>' '<head><base href="${upstream.htmlBase}">' ir;
        ''}
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: u: ''
          <a href="${u.path}" class="card">
            <h2>${name}</h2>
            <div class="path">${u.path}</div>
          </a>
          '') enabledUpstreams)}
        </div>
        <p class="footer">server.tail685690.ts.net</p>
      </div>
    </body>
    </html>
  '';

  dashboardDir = pkgs.runCommand "dashboard" { } ''
    mkdir -p $out
    cp ${dashboardHtml} $out/index.html
  '';

  # Tailscale serve URL
  tailscaleUrl = "http://${builtins.elemAt cfg.listenAddresses 0}:${toString cfg.port}";
in
{
  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      additionalModules = [ pkgs.nginxModules.subsFilter ];

      virtualHosts."_" = {
        listen = map (addr: { inherit addr; port = cfg.port; }) cfg.listenAddresses;

        extraConfig = ''
          ${cfg.extraNginxConfig}

          ${lib.optionalString cfg.dashboard.enable ''
          location = / {
            root ${dashboardDir};
            try_files /index.html =404;
          }
          ''}

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList locationBlock enabledUpstreams)}

          ${lib.concatStringsSep "\n" (lib.concatMap (u: u.extraLocations) (builtins.attrValues enabledUpstreams))}

          # Everything else: 404
          location / {
            return 404;
          }
        '';
      };
    };

    systemd.services.tailscale-serve = lib.mkIf cfg.tailscaleServe.enable {
      description = "Tailscale Serve — route :${toString cfg.tailscaleServe.httpsPort} to nginx reverse proxy";
      after = [ "tailscaled.service" "nginx.service" ];
      wants = [ "nginx.service" ];
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
