# Monitoring module options: Prometheus + Grafana observability stack.
{ lib, ... }:
{
  options.my.services.monitoring = {
    enable = lib.mkEnableOption "Prometheus + Grafana monitoring stack";

    nodeExporter = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Prometheus node-exporter on this host. Default true when the module is enabled — every monitored host exports metrics.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 9100;
        description = "Port for the node-exporter metrics endpoint.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address node-exporter binds to. Open the firewall if remote hosts scrape this host.";
      };
      openFirewall = lib.mkEnableOption "open the node-exporter port in the NixOS firewall";
    };

    prometheus = {
      enable = lib.mkEnableOption "Prometheus server (collector)";
      port = lib.mkOption {
        type = lib.types.port;
        default = 9090;
        description = "Port for the Prometheus server.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address Prometheus binds to. Grafana on the same host reaches it via localhost.";
      };
      scrapeTargets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Extra node-exporter scrape targets as "host:port" strings (e.g. "100.121.125.58:9100").
          The server's own localhost:9100 is always included automatically.
        '';
      };
    };

    grafana = {
      enable = lib.mkEnableOption "Grafana dashboard (proxied at /grafana)";
      port = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Port for Grafana. Default 3001: 3000 is used by open-webui on the server.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address Grafana binds to. Served through Caddy at /grafana.";
      };
      rootUrl = lib.mkOption {
        type = lib.types.str;
        description = "Full public URL used to access Grafana, including the /grafana subpath (e.g. https://server.tailXXXX.ts.net/grafana/).";
      };
      adminPasswordSecret = lib.mkOption {
        type = lib.types.str;
        default = "grafana-admin-password";
        description = "agenix secret name holding the Grafana admin password.";
      };
    };
  };
}
