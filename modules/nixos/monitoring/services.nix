# Monitoring module service wiring: reverse-proxy upstream registration and
# Grafana datasource provisioning. Plain function file imported from config.nix.
{ config, lib, ... }:
let
  cfg = config.my.services.monitoring;
in
{
  # ── Reverse proxy: Grafana at /grafana ─────────────────────────────────
  # Grafana runs with serve_from_sub_path = true, which 301-redirects any
  # request that lacks the /grafana prefix. The proxy must therefore
  # PRESERVE the prefix: stripPrefix = false → Caddy uses `handle` (not
  # `handle_path`), forwarding the full /grafana/... URI to Grafana. Using
  # handle_path here would strip /grafana and cause an infinite redirect
  # loop (verified against grafana v13 subpath_redirect.go).
  my.services.proxy.upstreams.grafana = lib.mkIf cfg.grafana.enable {
    displayName = "Grafana";
    port = cfg.grafana.port;
    host = cfg.grafana.listenAddress;
    path = "/grafana/";
    stripPrefix = false;
    # Caddy path matcher /grafana/* does NOT match bare /grafana; redirect it
    # to the canonical trailing-slash URL so Grafana's subpath handling kicks in.
    extraLocations = [
      ''
        handle /grafana {
          redir /grafana/ 308
        }
      ''
    ];
  };

  # ── Grafana datasource: provision Prometheus so dashboards work out of
  #    the box. Prometheus binds 127.0.0.1 so Grafana reaches it locally.
  services.grafana.provision.datasources.settings.datasources = lib.mkIf cfg.grafana.enable [
    {
      name = "Prometheus";
      type = "prometheus";
      access = "proxy";
      url = "http://127.0.0.1:${toString cfg.prometheus.port}";
      isDefault = true;
    }
  ];
}
