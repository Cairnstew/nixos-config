# Monitoring module config: option-gated orchestration of the nixpkgs
# prometheus/grafana/node-exporter services. Service wiring (proxy upstream,
# datasource provisioning) lives in services.nix, imported below.
{ config, lib, ... }:
let
  cfg = config.my.services.monitoring;
  hasGrafanaSecret = lib.hasAttr cfg.grafana.adminPasswordSecret config.age.secrets;

  # Service wiring (services.nix) — proxy upstream registration and Grafana
  # datasource provisioning. mkMerge (not //) so nested `services.grafana`
  # keys from both files merge at the option level instead of clobbering.
  services = import ./services.nix { inherit config lib; };
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    services
    {
      # ── Prometheus: node-exporter on every monitored host, plus the
      #    Prometheus server (collector) on the server host only.
      services.prometheus = lib.mkMerge [
        {
          exporters.node = lib.mkIf cfg.nodeExporter.enable {
            enable = true;
            port = cfg.nodeExporter.port;
            listenAddress = cfg.nodeExporter.listenAddress;
            openFirewall = cfg.nodeExporter.openFirewall;
          };
        }
        (lib.mkIf cfg.prometheus.enable {
          enable = true;
          port = cfg.prometheus.port;
          listenAddress = cfg.prometheus.listenAddress;
          scrapeConfigs = [
            {
              job_name = "node";
              static_configs = [
                {
                  targets = [ "localhost:${toString cfg.nodeExporter.port}" ] ++ cfg.prometheus.scrapeTargets;
                }
              ];
            }
          ];
        })
      ];

      # ── Grafana: dashboard (server host only) ────────────────────────────
      services.grafana = lib.mkIf cfg.grafana.enable {
        enable = true;
        settings = {
          server = {
            http_addr = cfg.grafana.listenAddress;
            http_port = cfg.grafana.port;
            # serve_from_sub_path = true: Grafana serves from the /grafana
            # subpath and 301-redirects any request missing it. The reverse
            # proxy MUST therefore preserve the /grafana prefix (handle, not
            # handle_path) — see services.nix upstream stripPrefix = false.
            root_url = cfg.grafana.rootUrl;
            serve_from_sub_path = true;
          };
          security = {
            admin_user = "admin";
          } // lib.optionalAttrs hasGrafanaSecret {
            # File provider keeps the password out of the world-readable Nix
            # store. Guarded so hosts without the secret (e.g. CI) still eval.
            admin_password = "$__file{${config.age.secrets.${cfg.grafana.adminPasswordSecret}.path}}";
          };
        };
      };
    }
  ]);
}
