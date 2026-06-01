{
  name = "tailscale";
  description = "Tailscale mesh VPN with static SSH config and optional OAuth-based auth key and ACL management (tailscale-manager)";
  category = "networking";
  tags = [ "networking" "vpn" "tailscale" "ssh" "acl" "terraform" ];
  provides = [ "my.services.tailscale" "my.services.tailscale.manager" ];
  expects = [ "my.secrets" "my.services.ssh" "tailscale-manager" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
