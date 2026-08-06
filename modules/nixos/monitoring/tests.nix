{ config, lib, ... }:
let
  cfg = config.my.services.monitoring;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.nodeExporter.enable;
      message = "my.services.monitoring: nodeExporter.enable is true by default; it must not be disabled when the monitoring module is enabled (every monitored host exports metrics).";
    }
    {
      assertion = !cfg.grafana.enable || cfg.prometheus.enable;
      message = "my.services.monitoring: prometheus.enable must be true when grafana.enable is set (Grafana provisions a Prometheus datasource).";
    }
    {
      assertion = !cfg.grafana.enable || cfg.grafana.rootUrl != "";
      message = "my.services.monitoring: grafana.rootUrl must be set (full public URL including /grafana, e.g. https://server.tailXXXX.ts.net/grafana/).";
    }
    {
      assertion = !cfg.grafana.enable || config.my.services.proxy.enable;
      message = "my.services.monitoring: grafana.enable requires my.services.proxy.enable (Grafana is exposed at /grafana through Caddy).";
    }
  ];
}
