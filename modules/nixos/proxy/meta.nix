{
  name = "proxy";
  description = "Unified Caddy reverse proxy with tailscale-serve for web services";
  category = "services";
  tags = [ "proxy" "nginx" "reverse-proxy" "tailscale" "web" ];
  provides = [
    "my.services.proxy"
    "my.services.proxy.dashboard.theme"
  ];
  complexity = "medium";
  # The dashboard page is generated as HTML + inline CSS/JS; theme.nix owns the
  # stylesheet and the colour names the JS interpolates.
  theme = {
    kind = "web";
    mechanism = "css-inject";
    file = "theme.nix";
  };
  tested = true;
  maintainer = "seanc";
}
