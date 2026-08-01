{
  name = "mss-clamp";
  description = "TCP MSS clamping on mesh tunnel interfaces to prevent MTU blackholes";
  category = "networking";
  tags = [ "networking" "mtu" "tailscale" "firewall" "iptables" "ssh" ];
  provides = [ "my.services.mssClamp" ];
  expects = [ "my.services.tailscale" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
}
