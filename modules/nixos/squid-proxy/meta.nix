{
  name = "squid-proxy";
  description = "Squid forward proxy for browser egress over Tailscale";
  category = "services";
  tags = [ "squid" "forward-proxy" "proxy" "tailscale" "networking" ];
  provides = [ "my.services.squidProxy" ];
  complexity = "low";
  tested = false;
  maintainer = "seanc";
}
