{
  name = "nixos-deploy-tool";
  description = "NixOS deploy tool: systemd service + CLI integration with auto-wired paths to agenix-manager, nixos-anywhere, and age";
  category = "deployment";
  tags = [ "deploy" "nixos-anywhere" "agenix" "secrets" "tailscale" ];
  provides = [
    "my.services.nixos-deploy-tool"
    "services.nixos-deploy-tool"
  ];
  complexity = "low";
  tested = true;
}
