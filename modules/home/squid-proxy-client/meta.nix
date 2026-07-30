{
  name = "squid-proxy-client";
  description = "Squid proxy client — qutebrowser configured for server forward-proxy";
  category = "services";
  tags = [ "squid" "proxy" "qutebrowser" "tailscale" ];
  provides = [ "my.programs.squidProxyClient" ];
  complexity = "low";
  tested = false;
  maintainer = "seanc";
}
