{
  name = "tailscale-manager";
  description = "Declarative Tailscale auth key management via Terraform";
  category = "networking";
  tags = [ "networking" "tailscale" "terraform" "auth" ];
  provides = [ "my.services.tailscale-manager" ];
  expects = [ "my.secrets" ];
  complexity = "low";
  tested = true;
  maintainer = "seanc";
}
