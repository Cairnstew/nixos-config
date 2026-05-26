# Boot Server Configuration
# Deploy via nixos-anywhere:
#   nix run github:nix-community/nixos-anywhere -- --flake .#bootserver root@<ip>
{ flake, ... }:
{
  imports = [
    # Replace with your own generated hardware-configuration.nix:
    #   nixos-generate-config --show-hardware-config > hardware-configuration.nix
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
    flake.inputs.self.nixosModules.pxe-server
  ];

  networking.hostName = "bootserver";
  nixpkgs.hostPlatform = "x86_64-linux";

  # ── Static IP for stable DHCP option 66 ────────────────────────────────
  networking.interfaces.eth0 = {
    ipv4.addresses = [{
      address = "192.168.100.1";
      prefixLength = 24;
    }];
    useDHCP = false;
  };

  # ── PXE Server ─────────────────────────────────────────────────────────
  my.services.pxeServer = {
    enable = true;
    interface = "eth0";
    dhcpRange = "192.168.100.100,192.168.100.200";
    serverIp = "192.168.100.1";
  };

  # ── Windows ISO Sync (populates the PXE server's /srv/pxe/windows/) ──
  my.services.windowsIsoSync.enable = true;
}
