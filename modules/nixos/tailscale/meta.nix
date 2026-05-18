{
  name = "tailscale";
  description = "Tailscale mesh VPN with static SSH configuration";
  category = "networking";
  tags = [ "networking" "vpn" "tailscale" "ssh" ];
  provides = [ "my.services.tailscale" ];
  expects = [ "my.secrets" "my.services.ssh" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
