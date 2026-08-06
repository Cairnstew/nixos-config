{
  name = "monitoring";
  description = "Prometheus + Grafana observability with node-exporter, subpath proxying, and tailnet scraping";
  category = "services";
  tags = [ "monitoring" "prometheus" "grafana" "node-exporter" "metrics" "observability" ];
  provides = [ "my.services.monitoring" ];
  expects = [ "my.services.proxy" "my.secrets" ];
  complexity = "medium";
  tested = false;
  maintainer = "seanc";
}
