{
  name = "monitoring";
  description = "Prometheus + Grafana observability with node-exporter, subpath proxying, and tailnet scraping";
  category = "services";
  tags = [ "monitoring" "prometheus" "grafana" "node-exporter" "metrics" "observability" ];
  provides = [
    "my.services.monitoring"
    "my.services.monitoring.theme"
  ];
  expects = [ "my.services.proxy" "my.secrets" ];
  complexity = "medium";
  # Grafana OSS has no custom-CSS hook; only users.default_theme follows the
  # palette polarity.
  theme = {
    kind = "web";
    mechanism = "native";
    file = "theme.nix";
  };
  tested = false;
  maintainer = "seanc";
}
