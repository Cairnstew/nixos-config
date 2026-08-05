{
  name = "proxy";
  description = "Unified Caddy reverse proxy with tailscale-serve for web services";
  category = "services";
  tags = [ "proxy" "nginx" "reverse-proxy" "tailscale" "web" ];
  provides = [ "my.services.proxy" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
