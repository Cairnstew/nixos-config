{
  name = "tailscale";
  description = "Tailscale mesh VPN with static SSH config and optional OAuth-based auth key and ACL management (tailscale-manager)";
  category = "networking";
  tags = [ "networking" "vpn" "tailscale" "ssh" "acl" "terraform" ];
  provides = [ "my.services.tailscale" "my.services.tailscale.manager" ];
  # G5: consumes config.age.secrets.* directly (agenix-manager), not my.secrets (an enable flag only)
  expects = [ "agenix-manager" "my.services.ssh" "tailscale-manager" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
}
