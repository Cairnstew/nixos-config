# Option-gated orchestration (F9c split): shared let-bindings, Caddyfile
# generation, and unit wiring. Dashboard HTML lives in dashboard.nix and the
# systemd units in services.nix — both plain function files imported below.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.proxy;

  # Expected tailscale0 MTU (null when the tailscale module isn't configured)
  tailscaleMtu = config.my.services.tailscale.mtu or null;
  tailscaleExpectedMtuJson = if tailscaleMtu != null then toString tailscaleMtu else "null";

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
  # Dashboard static page (dashboard.nix) — pure function of the enabled
  # upstreams and dashboard options; returns the buildable dashboard dir.
  dashboard = import ./dashboard.nix {
    inherit cfg enabledUpstreams lib pkgs;
  };

  # Dashboard directory (index.html) — aliased so the Caddyfile template
  # below keeps the original dashboardDir reference verbatim.
  dashboardDir = dashboard.dashboardDir;

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
      ${lib.optionalString cfg.systemMetrics.enable ''
      handle_path /api/metrics/* {
        root * /run/metrics
        file_server
      }
      ''}

      ${lib.concatStringsSep "\n" (map (i: ''
      handle_path ${i.apiPath}/* {
        reverse_proxy ${i.host}:${toString i.port} {
          ${lib.optionalString (i.apiAuthEnv != null) "header_up Authorization \"{\$${i.apiAuthEnv}}\""}
        }
      }
      '') cfg.dashboard.opencode)}

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList handleBlock enabledUpstreams)}

      ${lib.concatStringsSep "\n" (lib.concatMap (u: u.extraLocations) (builtins.attrValues enabledUpstreams))}

      ${lib.optionalString cfg.dashboard.enable ''
      handle /index.html {
        root * ${dashboardDir}
        file_server
      }
      handle {
        root * ${dashboardDir}
        file_server
      }
      ''}

      handle  {
        respond "Not Found" 404
      }

      ${cfg.extraConfig}
    }
  '';

  # Tailscale serve URL (uses the first listen address)
  tailscaleUrl = "http://${builtins.elemAt cfg.listenAddresses 0}:${toString cfg.port}";

  # Systemd unit definitions (services.nix) — caddy EnvironmentFile, metrics
  # collection service/timer, tmpfiles, and tailscale serve, built from the
  # Caddyfile, metrics script, and shared values above.
  services = import ./services.nix {
    inherit cfg tailscaleUrl tailscaleExpectedMtuJson lib pkgs;
  };
in
{
  # Enable Caddy with the generated Caddyfile, then merge the systemd unit
  # definitions from services.nix.
  config = lib.mkIf cfg.enable (services // {
    services.caddy = {
      enable = true;
      configFile = caddyfile;
    };
  });
}
